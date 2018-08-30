### Setting up iOS app
Since the "use without bluetooth" feature isn't done yet, you must use an iOS device with Xcode.

#### Steps
1. Plug an iOS device into your computer via USB
2. Download the fractal repo, and navigate to the `FractalPhone` directory via terminal. Run the `pod install` command. Here's what you should see:
```
» cd ios/iPhone/FractalPhone
» pod install

Analyzing dependencies
Downloading dependencies
Installing Alamofire (4.7.3)
Installing AudioKit (4.3)
Installing SwiftChart (1.0.1)
Generating Pods project
Integrating client project
Sending stats
Pod installation complete! There are 3 dependencies from the Podfile and 3 total pods installed.

[!] Automatically assigning platform `ios` with version `11.0` on target `Audio Processor` because no platform was specified. Please specify a platform for this target in your Podfile. See `https://guides.cocoapods.org/syntax/podfile.html#platform`.
```
3. open the file ``FractalPhone.xcworkspace`` (NOT FractalPhone.xcodeproj... that one does not include Pods). This will open Xcode.
4. In Xcode, at the top near the build button in the top left corner, click the button directly to the right of "Fractal". It will probably say "Generic iOS Device" to begin with
5. Select your iOS device from the top of the list under the Device tab. Xcode may direct you to do some permission settings.
6. Click the "play" button to build and run (or Cmd + R)
