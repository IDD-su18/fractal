package com.example.paigeplander.auscultator;

import android.support.v4.app.Fragment;
import android.net.Uri;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.design.widget.BottomNavigationView;
import android.support.v7.app.AppCompatActivity;
import android.view.MenuItem;
import android.widget.TextView;

public class MainActivity extends AppCompatActivity implements
        ScanFragment.OnScanFragmentInteractionListener,
        MonitorFragment.OnMonitorFragmentInteractionListener {

    ScanFragment scanFragment = new ScanFragment();
    MonitorFragment monitorFragment = new MonitorFragment();

    private BottomNavigationView.OnNavigationItemSelectedListener mOnNavigationItemSelectedListener
            = new BottomNavigationView.OnNavigationItemSelectedListener() {

        @Override
        public boolean onNavigationItemSelected(@NonNull MenuItem item) {
            switch (item.getItemId()) {
                case R.id.navigation_scan:
                    switchToFragment(scanFragment);
                    return true;
                case R.id.navigation_monitor:
                    switchToFragment(monitorFragment);
                    return true;
            }
            return false;
        }
    };

    @Override
    public void onMonitorFragmentInteraction(Uri uri){
        //you can leave it empty
    }

    @Override
    public void onScanFragmentInteraction(Uri uri){
        //you can leave it empty
    }


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        BottomNavigationView navigation = (BottomNavigationView) findViewById(R.id.navigation);
        navigation.setOnNavigationItemSelectedListener(mOnNavigationItemSelectedListener);


        // However, if we're being restored from a previous state,
        // then we don't need to do anything and should return or else
        // we could end up with overlapping fragments.
        if (savedInstanceState != null) {
            return;
        }
        scanFragment.setArguments(getIntent().getExtras());
        switchToFragment(scanFragment);

    }

    public void switchToFragment(Fragment fragment) {
        // Check that the activity is using the layout version with
        // the fragment_container FrameLayout
        if (findViewById(R.id.fragment_container) != null) {

            // Create a new Fragment to be placed in the activity layout

            // In case this activity was started with special instructions from an
            // Intent, pass the Intent's extras to the fragment as arguments


            // Add the fragment to the 'fragment_container' LinearLayout
            getSupportFragmentManager().beginTransaction()
                    .replace(R.id.fragment_container, fragment).commit();
        }
    }

}
