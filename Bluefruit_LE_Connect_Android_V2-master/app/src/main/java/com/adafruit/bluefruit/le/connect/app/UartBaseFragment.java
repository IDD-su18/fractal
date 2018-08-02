package com.adafruit.bluefruit.le.connect.app;

import android.Manifest;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.support.annotation.MainThread;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.ActivityCompat;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentManager;
import android.support.v4.content.ContextCompat;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.SpannableStringBuilder;
import android.text.style.ForegroundColorSpan;
import android.text.style.StyleSpan;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.SubMenu;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;

import com.adafruit.bluefruit.le.connect.R;
import com.adafruit.bluefruit.le.connect.ble.BleUtils;
import com.adafruit.bluefruit.le.connect.ble.UartPacket;
import com.adafruit.bluefruit.le.connect.ble.UartPacketManagerBase;
import com.adafruit.bluefruit.le.connect.ble.central.BlePeripheralUart;
import com.adafruit.bluefruit.le.connect.mqtt.MqttManager;
import com.adafruit.bluefruit.le.connect.mqtt.MqttSettings;
import com.adafruit.bluefruit.le.connect.utils.KeyboardUtils;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public abstract class UartBaseFragment extends ConnectedPeripheralFragment implements UartPacketManagerBase.Listener, MqttManager.MqttManagerListener, AdapterView.OnItemSelectedListener {
    // Log
    private final static String TAG = UartBaseFragment.class.getSimpleName();

    // Configuration
    public final static int kDefaultMaxPacketsToPaintAsText = 500;
    private final static int kInfoColor = Color.parseColor("#F21625");

    // Constants
    private final static String kPreferences = "UartActivity_prefs";
    private final static String kPreferences_eol = "eol";
    private final static String kPreferences_eolCharactersId = "eolCharactersId";
    private final static String kPreferences_echo = "echo";
    private final static String kPreferences_asciiMode = "ascii";
    private final static String kPreferences_timestampDisplayMode = "timestampdisplaymode";

    // UI
    private Button mSendButton;
    private MenuItem mMqttMenuItem;
    private Handler mMqttMenuItemAnimationHandler;


    // custom
    private static final String LOG_TAG = "AudioRecordTest";
    private static final int REQUEST_RECORD_AUDIO_PERMISSION = 200;
    private static String mFileName;

    String selectedSpinnerNumber = "0";
    private RecordButton mRecordButton;
    private MediaRecorder mRecorder;

    private PlayButton mPlayButton;
    private MediaPlayer mPlayer;

    private TextView titleTextView;



    // UI TextBuffer (refreshing the text buffer is managed with a timer because a lot of changes can arrive really fast and could stall the main thread)
    private Handler mUIRefreshTimerHandler = new Handler();
    private Runnable mUIRefreshTimerRunnable = new Runnable() {
        @Override
        public void run() {
            if (isUITimerRunning) {
                reloadData();
                // Log.d(TAG, "updateDataUI");
                mUIRefreshTimerHandler.postDelayed(this, 200);
            }
        }
    };
    private boolean isUITimerRunning = false;

    // Data
    protected final Handler mMainHandler = new Handler(Looper.getMainLooper());
    protected UartPacketManagerBase mUartData;
    protected List<BlePeripheralUart> mBlePeripheralsUart = new ArrayList<>();

    private boolean mShowDataInHexFormat;
    private boolean mIsTimestampDisplayMode;
    private boolean mIsEchoEnabled;
    private boolean mIsEolEnabled;
    private int mEolCharactersId;

    private volatile SpannableStringBuilder mTextSpanBuffer = new SpannableStringBuilder();

    protected MqttManager mMqttManager;

    private int maxPacketsToPaintAsText;
    private int mPacketsCacheLastSize = 0;

    // region Fragment Lifecycle
    public UartBaseFragment() {
        // Required empty public constructor
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Retain this fragment across configuration changes
        setRetainInstance(true);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        final Context context = getContext();

        // Setup Uart
        setupUart();

        Spinner spinner = (Spinner) view.findViewById(R.id.sounds_spinner);
        // Create an ArrayAdapter using the string array and a default spinner layout
        ArrayAdapter<CharSequence> adapter = ArrayAdapter.createFromResource(context,
                R.array.sound_indices, android.R.layout.simple_spinner_item);
        // Specify the layout to use when the list of choices appears
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        // Apply the adapter to the spinner
        spinner.setAdapter(adapter);
        spinner.setOnItemSelectedListener(this);


        //** AUDIO STUFF **//

        // Record to the external cache directory for visibility
        mFileName = getActivity().getExternalCacheDir().getAbsolutePath();
        mFileName += "/audiorecordtest.3gp";

        ActivityCompat.requestPermissions(getActivity(), permissions, REQUEST_RECORD_AUDIO_PERMISSION);
        titleTextView = (TextView) view.findViewById(R.id.title);
        LinearLayout ll = (LinearLayout) view.findViewById(R.id.recording_ll);
        mRecordButton = new RecordButton(context);




        // Buffer recycler view
        if (context != null) {

            ll.addView(mRecordButton,
                    new LinearLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            0));
            mPlayButton = new PlayButton(context);
            ll.addView(mPlayButton,
                    new LinearLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            0));

            DividerItemDecoration itemDecoration = new DividerItemDecoration(context, DividerItemDecoration.VERTICAL);
            Drawable lineSeparatorDrawable = ContextCompat.getDrawable(context, R.drawable.simpledivideritemdecoration);
            assert lineSeparatorDrawable != null;
            itemDecoration.setDrawable(lineSeparatorDrawable);


            LinearLayoutManager layoutManager = new LinearLayoutManager(context);
            //layoutManager.setStackFromEnd(true);        // Scroll to bottom when adding elements


        }

        // Buffer
//        mBufferTextView = view.findViewById(R.id.bufferTextView);
//        if (mBufferTextView != null) {
//            mBufferTextView.setKeyListener(null);     // make it not editable
//        }


        mSendButton = view.findViewById(R.id.sendButton);
        mSendButton.setOnClickListener(view12 -> onClickSend());

        final boolean isInMultiUartMode = isInMultiUartMode();



        // Counters

        // Read shared preferences
        maxPacketsToPaintAsText = kDefaultMaxPacketsToPaintAsText; //PreferencesFragment.getUartTextMaxPackets(this);

        // Read local preferences
        if (context != null) {
            SharedPreferences preferences = context.getSharedPreferences(kPreferences, Context.MODE_PRIVATE);
            setShowDataInHexFormat(!preferences.getBoolean(kPreferences_asciiMode, true));
            final boolean isTimestampDisplayMode = preferences.getBoolean(kPreferences_timestampDisplayMode, false);

            setEchoEnabled(preferences.getBoolean(kPreferences_echo, true));
            mIsEolEnabled = preferences.getBoolean(kPreferences_eol, true);
            mEolCharactersId = preferences.getInt(kPreferences_eolCharactersId, 0);
            FragmentActivity activity = getActivity();
            if (activity != null) {
                activity.invalidateOptionsMenu();        // update options menu with current values
            }

            // Mqtt init
            if (mMqttManager == null) {
                mMqttManager = new MqttManager(context, this);
                if (MqttSettings.isConnected(context)) {
                    mMqttManager.connectFromSavedSettings();
                }
            }
            else {
                mMqttManager.setListener(this);
            }
        }
    }

    private void setShowDataInHexFormat(boolean showDataInHexFormat) {
        mShowDataInHexFormat = showDataInHexFormat;


    }

    private void setEchoEnabled(boolean isEchoEnabled) {
        mIsEchoEnabled = isEchoEnabled;

    }

    abstract protected boolean isInMultiUartMode();

    @Override
    public void onResume() {
        super.onResume();

        FragmentActivity activity = getActivity();
        if (activity != null) {
            activity.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        }

        updateMqttStatus();

        updateBytesUI();

        isUITimerRunning = true;
        mUIRefreshTimerHandler.postDelayed(mUIRefreshTimerRunnable, 0);
    }

    @Override
    public void onPause() {
        super.onPause();

        //Log.d(TAG, "remove ui timer");
        isUITimerRunning = false;
        mUIRefreshTimerHandler.removeCallbacksAndMessages(mUIRefreshTimerRunnable);

        // Save preferences
        final Context context = getContext();
        if (context != null) {
            SharedPreferences preferences = context.getSharedPreferences(kPreferences, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = preferences.edit();
            editor.putBoolean(kPreferences_echo, mIsEchoEnabled);
            editor.putBoolean(kPreferences_eol, mIsEolEnabled);
            editor.putInt(kPreferences_eolCharactersId, mEolCharactersId);
            editor.putBoolean(kPreferences_asciiMode, !mShowDataInHexFormat);
            editor.putBoolean(kPreferences_timestampDisplayMode, mIsTimestampDisplayMode);

            editor.apply();
        }
    }

    @Override
    public void onDestroy() {
        mUartData = null;

        // Disconnect mqtt
        if (mMqttManager != null) {
            mMqttManager.disconnect();
        }

        // Uart
        if (mBlePeripheralsUart != null) {
            for (BlePeripheralUart blePeripheralUart : mBlePeripheralsUart) {
                blePeripheralUart.uartDisable();
            }
            mBlePeripheralsUart.clear();
            mBlePeripheralsUart = null;
        }

        super.onDestroy();
    }

    @Override
    public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {
        super.onCreateOptionsMenu(menu, inflater);
        inflater.inflate(R.menu.menu_uart, menu);

        // Mqtt
        mMqttMenuItem = menu.findItem(R.id.action_mqttsettings);
        mMqttMenuItemAnimationHandler = new Handler();
        mMqttMenuItemAnimationRunnable.run();

        // DisplayMode
        MenuItem displayModeMenuItem = menu.findItem(R.id.action_displaymode);
        displayModeMenuItem.setTitle(String.format("%s: %s", getString(R.string.uart_settings_displayMode_title), getString(mIsTimestampDisplayMode ? R.string.uart_settings_displayMode_timestamp : R.string.uart_settings_displayMode_text)));
        SubMenu displayModeSubMenu = displayModeMenuItem.getSubMenu();
        if (mIsTimestampDisplayMode) {
            MenuItem displayModeTimestampMenuItem = displayModeSubMenu.findItem(R.id.action_displaymode_timestamp);
            displayModeTimestampMenuItem.setChecked(true);
        } else {
            MenuItem displayModeTextMenuItem = displayModeSubMenu.findItem(R.id.action_displaymode_text);
            displayModeTextMenuItem.setChecked(true);
        }

        // DataMode
        MenuItem dataModeMenuItem = menu.findItem(R.id.action_datamode);
        dataModeMenuItem.setTitle(String.format("%s: %s", getString(R.string.uart_settings_dataMode_title), getString(mShowDataInHexFormat ? R.string.uart_settings_dataMode_hex : R.string.uart_settings_dataMode_ascii)));
        SubMenu dataModeSubMenu = dataModeMenuItem.getSubMenu();
        if (mShowDataInHexFormat) {
            MenuItem dataModeHexMenuItem = dataModeSubMenu.findItem(R.id.action_datamode_hex);
            dataModeHexMenuItem.setChecked(true);
        } else {
            MenuItem dataModeAsciiMenuItem = dataModeSubMenu.findItem(R.id.action_datamode_ascii);
            dataModeAsciiMenuItem.setChecked(true);
        }

        // Echo
        MenuItem echoMenuItem = menu.findItem(R.id.action_echo);
        echoMenuItem.setTitle(R.string.uart_settings_echo_title);
        echoMenuItem.setChecked(mIsEchoEnabled);

        // Eol
        MenuItem eolMenuItem = menu.findItem(R.id.action_eol);
        eolMenuItem.setTitle(R.string.uart_settings_eol_title);
        eolMenuItem.setChecked(mIsEolEnabled);

        // Eol Characters
        MenuItem eolModeMenuItem = menu.findItem(R.id.action_eolmode);
        eolModeMenuItem.setTitle(String.format("%s: %s", getString(R.string.uart_settings_eolCharacters_title), getString(getEolCharactersStringId())));
        SubMenu eolModeSubMenu = eolModeMenuItem.getSubMenu();
        int selectedEolCharactersSubMenuId;
        switch (mEolCharactersId) {
            case 1:
                selectedEolCharactersSubMenuId = R.id.action_eolmode_r;
                break;
            case 2:
                selectedEolCharactersSubMenuId = R.id.action_eolmode_nr;
                break;
            case 3:
                selectedEolCharactersSubMenuId = R.id.action_eolmode_rn;
                break;
            default:
                selectedEolCharactersSubMenuId = R.id.action_eolmode_n;
                break;
        }
        MenuItem selectedEolCharacterMenuItem = eolModeSubMenu.findItem(selectedEolCharactersSubMenuId);
        selectedEolCharacterMenuItem.setChecked(true);
    }


    @Override
    public void onDestroyOptionsMenu() {
        super.onDestroyOptionsMenu();

        mMqttMenuItemAnimationHandler.removeCallbacks(mMqttMenuItemAnimationRunnable);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        FragmentActivity activity = getActivity();
        if (activity == null) {
            return super.onOptionsItemSelected(item);
        }

        switch (item.getItemId()) {
            case R.id.action_help: {
                FragmentManager fragmentManager = activity.getSupportFragmentManager();
                if (fragmentManager != null) {
//                    CommonHelpFragment helpFragment = CommonHelpFragment.newInstance(getString(R.string.uart_help_title), getString(R.string.uart_help_text));
//                    FragmentTransaction fragmentTransaction = fragmentManager.beginTransaction()
//                            .replace(R.id.contentLayout, helpFragment, "Help");
//                    fragmentTransaction.addToBackStack(null);
//                    fragmentTransaction.commit();
                }
                return true;
            }

            case R.id.action_displaymode_timestamp: {

                invalidateTextView();
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_displaymode_text: {

                invalidateTextView();
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_datamode_hex: {
                setShowDataInHexFormat(true);
                invalidateTextView();
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_datamode_ascii: {
                setShowDataInHexFormat(false);
                invalidateTextView();
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_echo: {
                setEchoEnabled(!mIsEchoEnabled);
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_eol: {
                mIsEolEnabled = !mIsEolEnabled;
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_eolmode_n: {
                mEolCharactersId = 0;
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_eolmode_r: {
                mEolCharactersId = 1;
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_eolmode_nr: {
                mEolCharactersId = 2;
                activity.invalidateOptionsMenu();
                return true;
            }

            case R.id.action_eolmode_rn: {
                mEolCharactersId = 3;
                activity.invalidateOptionsMenu();
                return true;
            }

            default: {
                return super.onOptionsItemSelected(item);
            }
        }
    }

    // endregion

    public void onItemSelected(AdapterView<?> parent, View view,
                               int pos, long id) {
        // An item was selected. You can retrieve the selected item using
        // parent.getItemAtPosition(pos)
        selectedSpinnerNumber = parent.getItemAtPosition(pos).toString();
    }

    public void onNothingSelected(AdapterView<?> parent) {
        // Another interface callback
    }

    // region Uart
    protected abstract void setupUart();

    protected abstract void send(String message);

    private void onClickSend() {
        send(selectedSpinnerNumber);
    }

    // endregion

    // region UI
    protected void updateUartReadyUI(boolean isReady) {
        if (mSendButton != null) {
            mSendButton.setEnabled(isReady);
        }

    }

    private void addTextToSpanBuffer(SpannableStringBuilder spanBuffer, String text, int color, boolean isBold) {
        final int from = spanBuffer.length();
        spanBuffer.append(text);
        spanBuffer.setSpan(new ForegroundColorSpan(color), from, from + text.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        if (isBold) {
            spanBuffer.setSpan(new StyleSpan(android.graphics.Typeface.BOLD), from, from + text.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
    }

    @MainThread
    private void updateBytesUI() {

    }


    abstract protected int colorForPacket(UartPacket packet);

    private boolean isFontBoldForPacket(UartPacket packet) {
        return packet.getMode() == UartPacket.TRANSFERMODE_TX;
    }

    private void invalidateTextView() {
        if (!mIsTimestampDisplayMode) {
            mPacketsCacheLastSize = 0;
            mTextSpanBuffer.clear();
            //mBufferTextView.setText("");
        }
    }

    private void reloadData() {
        List<UartPacket> packetsCache = mUartData.getPacketsCache();
        final int packetsCacheSize = packetsCache.size();
        if (mPacketsCacheLastSize != packetsCacheSize) {        // Only if the buffer has changed


            if (packetsCacheSize > maxPacketsToPaintAsText) {
                mPacketsCacheLastSize = packetsCacheSize - maxPacketsToPaintAsText;
                mTextSpanBuffer.clear();
                addTextToSpanBuffer(mTextSpanBuffer, getString(R.string.uart_text_dataomitted) + "\n", kInfoColor, false);
            }

            // Log.d(TAG, "update packets: "+(bufferSize-mPacketsCacheLastSize));
            for (int i = mPacketsCacheLastSize; i < packetsCacheSize; i++) {
                final UartPacket packet = packetsCache.get(i);
                onUartPacketText(packet);
            }

            //mBufferTextView.setText(mTextSpanBuffer);
            // mBufferTextView.setSelection(0, mTextSpanBuffer.length());        // to automatically scroll to the end
        }

        mPacketsCacheLastSize = packetsCacheSize;
    }




    // endregion

    // region Mqtt UI
    private Runnable mMqttMenuItemAnimationRunnable = new Runnable() {
        @Override
        public void run() {
            updateMqttStatus();
            mMqttMenuItemAnimationHandler.postDelayed(mMqttMenuItemAnimationRunnable, 500);
        }
    };
    private int mMqttMenuItemAnimationFrame = 0;

    @MainThread
    private void updateMqttStatus() {
        if (mMqttMenuItem == null) {
            return;      // Hack: Sometimes this could have not been initialized so we don't update icons
        }

        MqttManager.MqqtConnectionStatus status = mMqttManager.getClientStatus();

        if (status == MqttManager.MqqtConnectionStatus.CONNECTING) {
            final int kConnectingAnimationDrawableIds[] = {R.drawable.mqtt_connecting1, R.drawable.mqtt_connecting2, R.drawable.mqtt_connecting3};
            mMqttMenuItem.setIcon(kConnectingAnimationDrawableIds[mMqttMenuItemAnimationFrame]);
            mMqttMenuItemAnimationFrame = (mMqttMenuItemAnimationFrame + 1) % kConnectingAnimationDrawableIds.length;
        } else if (status == MqttManager.MqqtConnectionStatus.CONNECTED) {
            mMqttMenuItem.setIcon(R.drawable.mqtt_connected);
            mMqttMenuItemAnimationHandler.removeCallbacks(mMqttMenuItemAnimationRunnable);
        } else {
            mMqttMenuItem.setIcon(R.drawable.mqtt_disconnected);
            mMqttMenuItemAnimationHandler.removeCallbacks(mMqttMenuItemAnimationRunnable);
        }
    }

    // endregion

    // region Eol

    private String getEolCharacters() {
        switch (mEolCharactersId) {
            case 1:
                return "\r";
            case 2:
                return "\n\r";
            case 3:
                return "\r\n";
            default:
                return "\n";
        }
    }

    private int getEolCharactersStringId() {
        switch (mEolCharactersId) {
            case 1:
                return R.string.uart_eolmode_r;
            case 2:
                return R.string.uart_eolmode_nr;
            case 3:
                return R.string.uart_eolmode_rn;
            default:
                return R.string.uart_eolmode_n;
        }
    }

    // endregion

    // region UI

    private void onUartPacketText(UartPacket packet) {
        if (mIsEchoEnabled || packet.getMode() == UartPacket.TRANSFERMODE_RX) {
            final int color = colorForPacket(packet);
            final boolean isBold = isFontBoldForPacket(packet);
            final byte[] bytes = packet.getData();
            final String formattedData = mShowDataInHexFormat ? BleUtils.bytesToHex2(bytes) : BleUtils.bytesToText(bytes, true);
            addTextToSpanBuffer(mTextSpanBuffer, formattedData, color, isBold);
        }
    }

    private static SpannableString stringFromPacket(UartPacket packet, boolean useHexMode, int color, boolean isBold) {
        final byte[] bytes = packet.getData();
        final String formattedData = useHexMode ? BleUtils.bytesToHex2(bytes) : BleUtils.bytesToText(bytes, true);
        final SpannableString formattedString = new SpannableString(formattedData);
        formattedString.setSpan(new ForegroundColorSpan(color), 0, formattedString.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        if (isBold) {
            formattedString.setSpan(new StyleSpan(android.graphics.Typeface.BOLD), 0, formattedString.length(), Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        return formattedString;
    }

    // endregion

    // region UartPacketManagerBase.Listener

    @Override
    public void onUartPacket(UartPacket packet) {
        updateBytesUI();
    }

    // endregion

    // region MqttManagerListener

    @MainThread
    @Override
    public void onMqttConnected() {
        updateMqttStatus();
    }

    @MainThread
    @Override
    public void onMqttDisconnected() {
        updateMqttStatus();
    }

    // endregion

    // region Buffer Adapter

    class TimestampItemAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

        // ViewHolder
        class ItemViewHolder extends RecyclerView.ViewHolder {
            ViewGroup mainViewGroup;
            TextView timestampTextView;
            TextView dataTextView;

            ItemViewHolder(View view) {
                super(view);

                mainViewGroup = view.findViewById(R.id.mainViewGroup);
                timestampTextView = view.findViewById(R.id.timestampTextView);
                dataTextView = view.findViewById(R.id.dataTextView);
            }
        }

        // Data
        private Context mContext;
        private boolean mIsEchoEnabled;
        private boolean mShowDataInHexFormat;
        private UartPacketManagerBase mUartData;
        private List<UartPacket> mTableCachedDataBuffer;
        private SimpleDateFormat mDateFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());

        TimestampItemAdapter(@NonNull Context context) {
            super();
            mContext = context;
        }

        void setUartData(@Nullable UartPacketManagerBase uartData) {
            mUartData = uartData;
            notifyDataSetChanged();
        }

        int getCachedDataBufferSize() {
            return mTableCachedDataBuffer != null ? mTableCachedDataBuffer.size() : 0;
        }

        void setEchoEnabled(boolean isEchoEnabled) {
            mIsEchoEnabled = isEchoEnabled;
            notifyDataSetChanged();
        }

        void setShowDataInHexFormat(boolean showDataInHexFormat) {
            mShowDataInHexFormat = showDataInHexFormat;
            notifyDataSetChanged();
        }

        @NonNull
        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.layout_uart_packetitem, parent, false);
            return new TimestampItemAdapter.ItemViewHolder(view);
        }

        @Override
        public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
            ItemViewHolder itemViewHolder = (ItemViewHolder) holder;

            UartPacket packet = mTableCachedDataBuffer.get(position);
            final String currentDateTimeString = mDateFormat.format(new Date(packet.getTimestamp()));//DateFormat.getTimeInstance().format(new Date(packet.getTimestamp()));
            final String modeString = mContext.getString(packet.getMode() == UartPacket.TRANSFERMODE_RX ? R.string.uart_timestamp_direction_rx : R.string.uart_timestamp_direction_tx);

            itemViewHolder.timestampTextView.setText(String.format("%s %s", currentDateTimeString, modeString));



            itemViewHolder.mainViewGroup.setBackgroundColor(position % 2 == 0 ? Color.WHITE : 0xeeeeee);
        }

        @Override
        public int getItemCount() {
            if (mUartData == null) {
                return 0;
            }

            if (mIsEchoEnabled) {
                mTableCachedDataBuffer = mUartData.getPacketsCache();
            } else {
                if (mTableCachedDataBuffer == null) {
                    mTableCachedDataBuffer = new ArrayList<>();
                } else {
                    mTableCachedDataBuffer.clear();
                }

                List<UartPacket> packets = mUartData.getPacketsCache();
                for (int i = 0; i < packets.size(); i++) {
                    UartPacket packet = packets.get(i);
                    if (packet.getMode() == UartPacket.TRANSFERMODE_RX) {
                        mTableCachedDataBuffer.add(packet);
                    }
                }
            }

            return mTableCachedDataBuffer.size();
        }
    }



    public class RecordButton extends Button {
        boolean mStartRecording = true;

        OnClickListener clicker = new OnClickListener() {
            public void onClick(View v) {
                onRecord(mStartRecording);
                if (mStartRecording) {
                    titleTextView.setText("Scan in progress");
                    setText("Stop recording");
                } else {
                    titleTextView.setText("Scan complete");
                    setText("Start recording");
                }
                mStartRecording = !mStartRecording;
            }
        };

        public RecordButton(Context ctx) {
            super(ctx);
            setText("Start recording");
            setOnClickListener(clicker);
        }
    }



    class PlayButton extends Button {
        boolean mStartPlaying = true;

        OnClickListener clicker = new OnClickListener() {
            public void onClick(View v) {
                onPlay(mStartPlaying);
                if (mStartPlaying) {
                    setText("Stop playing");
                } else {
                    setText("Start playing");
                }
                mStartPlaying = !mStartPlaying;
            }
        };

        public PlayButton(Context ctx) {
            super(ctx);
            setText("Start playing");
            setOnClickListener(clicker);
        }

    }



    // Requesting permission to RECORD_AUDIO
    private boolean permissionToRecordAccepted = false;
    private String [] permissions = {Manifest.permission.RECORD_AUDIO};

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        switch (requestCode){
            case REQUEST_RECORD_AUDIO_PERMISSION:
                permissionToRecordAccepted  = grantResults[0] == PackageManager.PERMISSION_GRANTED;
                break;
        }
        // return was finish before, hopefully this doesnt mess w/ things
        if (!permissionToRecordAccepted ) return;

    }

    private void onRecord(boolean start) {
        if (start) {

            startRecording();
        } else {
            stopRecording();
        }
    }

    private void onPlay(boolean start) {
        if (start) {
            startPlaying();
        } else {
            stopPlaying();
        }
    }

    private void startPlaying() {
        mPlayer = new MediaPlayer();
        try {
            mPlayer.setDataSource(mFileName);
            mPlayer.prepare();
            mPlayer.start();
        } catch (IOException e) {
            Log.e(LOG_TAG, "prepare() failed");
        }
    }

    private void stopPlaying() {
        mPlayer.release();
        mPlayer = null;
    }

    private void startRecording() {
        mRecorder = new MediaRecorder();
        mRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mRecorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
        mRecorder.setOutputFile(mFileName);
        mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);

        try {
            mRecorder.prepare();
        } catch (IOException e) {
            Log.e(LOG_TAG, "prepare() failed");
        }

        mRecorder.start();
    }

    private void stopRecording() {
        mRecorder.stop();
        mRecorder.release();
        mRecorder = null;
    }


    @Override
    public void onStop() {
        super.onStop();
        if (mRecorder != null) {
            mRecorder.release();
            mRecorder = null;
        }

        if (mPlayer != null) {
            mPlayer.release();
            mPlayer = null;
        }
    }
}
