# Zone

Zone is an app blocker for iPhone. Tap a button to enter the Zone, and the apps you chose are blocked. To leave, you must scan your NFC tag.

<p>
  <img src="docs/home.png" width="200" alt="Home">
  <img src="docs/month.png" width="200" alt="Analytics, month">
  <img src="docs/week.png" width="200" alt="Analytics, week">
  <img src="docs/settings.png" width="200" alt="Settings">
</p>

## Features

- Blocks apps and websites with Screen Time.
- Leave only with your own tag. Zone checks the tag chip ID, so a copy of the sticker does not work.
- Super Zone locks again some minutes after you leave, also when the app is closed.
- Analytics shows your time in the Zone for each day of the month and for the last 7 days. Tap a day to see its total.

## Install

### TestFlight

You need an NFC tag, for example an NTAG213 sticker.

1. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) from the App Store.
2. On your iPhone, open https://testflight.apple.com/join/kjdW6w6b and tap Install.

Updates: TestFlight installs new versions for you. If it does not, open TestFlight and tap Update.

### Build from source

You need a Mac with Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and a paid Apple developer account. A free Apple ID cannot use Screen Time controls.

1. Get the code:

   ```sh
   git clone https://github.com/nethum529/zone.git
   cd zone
   ```

2. Use your own team ID and bundle ID prefix. Find your team ID in the [developer account](https://developer.apple.com/account) under Membership details.

   ```sh
   sed -i '' 's/NYKPX446L9/YOUR_TEAM_ID/; s/com\.nethum/com.yourname/g' project.yml Shared/ZoneLock.swift
   ```

3. Make the project and open it:

   ```sh
   xcodegen generate
   open Zone.xcodeproj
   ```

4. Connect your iPhone, select it at the top of Xcode, and press Run (Cmd+R).

Updates:

```sh
git pull --autostash
xcodegen generate
```

Then press Run in Xcode again. Your Zone data stays on the phone.

Icons are from [Phosphor](https://phosphoricons.com) (MIT).
