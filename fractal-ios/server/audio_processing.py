import matplotlib
matplotlib.use('Agg')
import numpy as np
import csv
import matplotlib.pyplot as plt # naming convention for matplotlib
from scipy.io import wavfile as wav
from scipy.fftpack import fft # import discrete fourier transform and its inverse
from scipy import signal
from scipy.io.wavfile import write


def process_file(audio_file):
    #Read in the file upload
    #FOR EXAMPLE: Folder: Bone Transducer, fileName = BoneTransducer_T02_2
    #don't include .wav for obvious reasons
    fileName = 'brp_h_t06'
    sampFreq, snd = wav.read(fileName + '.wav')

    # PREPROCESSING DATA

    # ZERO-MEAN
    snd = (snd - snd.mean()) / snd.std()
    #snd = snd[50000:1450000] #used for dropouts

    # 60 HZ INTERFERENCE NOTCH FILTER
    f0 = 60.0  # Frequency to be removed from signal (Hz)
    Q = 40.0  # Quality factor
    w0 = f0/(sampFreq/2)  # Normalized Frequency
    # Design notch filter
    b, a = signal.iirnotch(w0, Q)
    snd = signal.filtfilt(b, a, snd)

    # INITIALIZE
    fig = plt.figure()

    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(nrows=2, ncols=2, figsize=(15,10))

    file_len = len(snd)

    # PLOT AUDIO WAVEFORM
    timeArray = np.arange(0, len(snd), 1)
    timeArray = timeArray / sampFreq
    print("Length of file: " + str(len(snd)/sampFreq) + "s")
    #snd_norm = np.amax(snd)
    #ax1.plot(timeArray, snd/snd_norm, color='k')
    ax1.plot(timeArray, snd, color='k')
    ax1.set_title('Audio Waveform')
    ax1.set_xlabel('Time (s)')
    ax1.set_ylabel('Amplitude')

    # CALCULATE FFT

    dft = fft(snd[:490000]) # calculate fourier transform
    N = len(dft) # length of discrete fourier transform
    freqs = [i*sampFreq/N for i in range(N)] # convert from dft frequencies to Hz
    #dft_norm = np.amax(np.abs(dft))
    #ax2.plot(freqs, np.abs(dft)/dft_norm, color='k') # change the indices to zoom in/out in frequency
    ax2.plot(freqs, np.abs(dft), color='k') # change the indices to zoom in/out in frequency
    ax2.set_title('Freq Analysis')
    ax2.set_xlabel('Frequencies (Hz)')
    ax2.set_ylabel('DFT Coefficients')
    ax2.set_xlim([0,1000])

    # CALCULATE SPECTROGRAM

    Pxx, freqs, bins, im = ax3.specgram(snd, NFFT=1024, Fs=sampFreq)
    ax3.set_title('Spectrogram')
    ax3.set_xlabel('Time')
    ax3.set_ylabel('Frequency')
    ax3.set_ylim([0,1000])

    # CALCULATE PSD (based on Welch)
    f, Pxx_den = signal.welch(snd[:file_len], sampFreq, nperseg=1024) #PLACE INDEX HERE
    #Pxx_den_norm = np.amax(Pxx_den)
    #ax4.plot(f, Pxx_den/Pxx_den_norm, color='k')
    ax4.plot(f, Pxx_den, color='k')
    ax4.set_title('PSD (Welch)')
    ax4.set_xlabel('Frequency [Hz]')
    ax4.set_ylabel('PSD [V^2/Hz]')
    ax4.set_xlim([0,1000])

    # POST-CALCULATION AESTHETIC

    plt.suptitle('Results for ' + fileName, fontsize=20)
    plt.tight_layout(rect=[0, 0.03, 1, 0.92])

    figure_name = fileName + '.png'
    fig.savefig(figure_name, bbox_inches='tight')
    print("Saved!")
    return figure_name

if __name__ == "__main__":
    process_file(None)
