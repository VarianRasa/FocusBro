# FocusBro

FocusBro is a Flutter productivity and focus application for mobile, desktop, and web. This repository also contains documentation website pages and a separate `web_app/` Flutter package.

## 🌟 Features

- **Modern Design**: Clean, responsive design with Material Design principles
- **Multilingual Support**: English and Indonesian language support
- **Comprehensive Documentation**: Complete guides for all app features
- **Mobile-First**: Optimized for all device sizes
- **Fast Loading**: Optimized performance with minimal dependencies

## 📁 Project Structure

```
focusbro-website/
├── index.html                 # Homepage
├── docs/                      # Documentation pages
│   ├── getting-started.html   # Installation and setup guide
│   ├── features.html          # Comprehensive features guide
│   ├── user-guide.html        # Step-by-step tutorials
│   └── faq.html              # Frequently asked questions
├── assets/
│   ├── css/
│   │   ├── style.css         # Main styles
│   │   ├── responsive.css    # Responsive design
│   │   └── docs.css          # Documentation-specific styles
│   ├── js/
│   │   └── main.js           # JavaScript functionality
│   ├── images/               # Images and icons
│   └── downloads/            # APK files
├── privacy.html              # Privacy Policy
├── terms.html                # Terms of Service
└── README.md                 # This file
```

## Dart Formatting

Configure the repository pre-commit hook once per clone:

```bash
git config core.hooksPath .githooks
```

The hook checks staged Dart files with the Dart SDK formatter and blocks commits when they need formatting. Ensure `dart` is available on `PATH` for Git.

Format the Flutter application and web package with the Dart SDK formatter:

```bash
dart format lib test integration_test test_driver web_app/lib
```

Check formatting without modifying files:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_driver web_app/lib
```

Run the check before submitting changes. A non-zero exit means at least one Dart file needs formatting.

## 🚀 Getting Started

### Flutter Application

The repository root is the primary Flutter application. Install Flutter for the SDK range in `pubspec.yaml`, then run:

```bash
flutter pub get
flutter analyze
flutter test
```

`web_app/` is a separate Flutter package. Run `flutter pub get`, `flutter analyze`, and `flutter test` from that directory. Device QA and Firebase emulator instructions are in `docs/android-smoke-qa.md` and `docs/firebase-development.md`.

### Documentation Website

1. Clone or download the website files
2. Open `index.html` in a web browser
3. For local server (recommended):
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Using Node.js
   npx serve .
   
   # Using PHP
   php -S localhost:8000
   ```

### Deployment

#### GitHub Pages (Recommended)
1. Create a new repository on GitHub
2. Upload all website files
3. Go to Settings > Pages
4. Select source branch (usually `main`)
5. Your site will be available at `https://username.github.io/repository-name`

#### Netlify
1. Drag and drop the website folder to [Netlify](https://netlify.com)
2. Your site will be deployed automatically

#### Vercel
1. Install Vercel CLI: `npm i -g vercel`
2. Run `vercel` in the website directory
3. Follow the deployment prompts

## 🎨 Customization

### Colors
Edit CSS custom properties in `assets/css/style.css`:
```css
:root {
    --primary-color: #6366f1;
    --secondary-color: #10b981;
    --accent-color: #f59e0b;
    /* ... other colors */
}
```

### Content
- **Homepage**: Edit `index.html`
- **Documentation**: Edit files in `docs/` folder
- **Translations**: Update the `translations` object in `assets/js/main.js`

### Images
Replace images in `assets/images/`:
- `focusbro-logo.png` - Main logo
- `favicon.png` - Browser favicon
- `app-mockup.png` - App screenshot for hero section
- `qr-code.png` - QR code for download

## 📱 APK Management

### Adding New APK Version
1. Build new APK from Flutter project:
   ```bash
   flutter build apk --release --no-tree-shake-icons
   ```
2. Copy APK to `assets/downloads/` with version naming:
   ```bash
   cp build/app/outputs/flutter-apk/app-release.apk assets/downloads/focusbro-v1.1.0.apk
   ```
3. Update download links in HTML files
4. Update version information in documentation

### APK Size Optimization
- Use `--split-per-abi` for smaller APKs:
  ```bash
  flutter build apk --release --split-per-abi --no-tree-shake-icons
  ```

## 🌐 Multilingual Support

### Adding New Language
1. Add language data to `translations` object in `assets/js/main.js`
2. Add language button to navigation
3. Update `switchLanguage()` function if needed

### Translation Format
```javascript
translations: {
    'en': {
        'key': 'English text'
    },
    'id': {
        'key': 'Indonesian text'
    },
    'new_lang': {
        'key': 'New language text'
    }
}
```

## 🔧 Technical Details

### Dependencies
- **Google Fonts**: Poppins font family
- **Font Awesome**: Icons (CDN)
- **No JavaScript frameworks**: Vanilla JS for better performance

### Browser Support
- Chrome 60+
- Firefox 60+
- Safari 12+
- Edge 79+

### Performance
- Optimized images
- Minified CSS/JS (for production)
- Lazy loading for images
- Efficient animations

## 📊 Analytics (Optional)

To add Google Analytics:
1. Get tracking ID from Google Analytics
2. Add tracking code to all HTML files before `</head>`:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_TRACKING_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_TRACKING_ID');
</script>
```

## 🛠️ Maintenance

### Regular Updates
- Update APK files when new app versions are released
- Update documentation when new features are added
- Check and update external CDN links
- Test website on different devices and browsers

### SEO Optimization
- Update meta descriptions for better search visibility
- Add structured data markup
- Optimize images with proper alt tags
- Ensure fast loading times

## 📄 License

This website is part of the FocusBro project. All rights reserved.

## 🤝 Contributing

To contribute to the website:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For website issues or suggestions:
- Create an issue in the repository
- Contact the development team
- Check the FAQ section

---

**FocusBro Website** - Boost your productivity with the ultimate focus and task management app.
