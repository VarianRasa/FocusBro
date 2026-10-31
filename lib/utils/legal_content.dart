/// Legal content for Privacy Policy and Terms of Service
class LegalContent {
  static String get privacyPolicyHtml => '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FocusBro Privacy Policy</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
            background-color: #fff;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            color: #2196F3;
            border-bottom: 3px solid #2196F3;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        h2 {
            color: #1976D2;
            margin-top: 30px;
            margin-bottom: 15px;
        }
        h3 {
            color: #1565C0;
            margin-top: 25px;
            margin-bottom: 10px;
        }
        .last-updated {
            background-color: #E3F2FD;
            padding: 10px;
            border-radius: 8px;
            margin-bottom: 30px;
            font-size: 14px;
            color: #1976D2;
        }
        .highlight {
            background-color: #FFF3E0;
            padding: 15px;
            border-left: 4px solid #FF9800;
            margin: 20px 0;
        }
        ul {
            padding-left: 20px;
        }
        li {
            margin-bottom: 8px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            text-align: center;
            color: #666;
            font-size: 14px;
        }
        .contact-info {
            background-color: #F5F5F5;
            padding: 20px;
            border-radius: 8px;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 FocusBro Privacy Policy</h1>
        
        <div class="last-updated">
            <strong>Last updated:</strong> ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
        </div>

        <div class="highlight">
            <strong>Your Privacy Matters:</strong> We are committed to protecting your privacy and being transparent about our data practices.
        </div>

        <h2>1. Introduction</h2>
        <p>FocusBro ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.</p>

        <h2>2. Information We Collect</h2>
        <h3>Personal Information</h3>
        <ul>
            <li>Name and email address (if provided)</li>
            <li>User preferences and settings</li>
            <li>Account information (if you create an account)</li>
        </ul>

        <h3>Usage Data</h3>
        <ul>
            <li>App usage statistics and session data</li>
            <li>Focus time and productivity metrics</li>
            <li>Feature usage patterns</li>
            <li>Performance and crash data</li>
        </ul>

        <h3>Device Information</h3>
        <ul>
            <li>Device type and operating system version</li>
            <li>App version and build information</li>
            <li>Device identifiers (for analytics purposes)</li>
        </ul>

        <h3>Local Data</h3>
        <ul>
            <li>Tasks, notes, and timer presets</li>
            <li>App settings and preferences</li>
            <li>PDF annotations and bookmarks</li>
            <li>Music playlists and preferences</li>
        </ul>

        <h2>3. How We Use Your Information</h2>
        <p>We use your information to:</p>
        <ul>
            <li>Provide and maintain the FocusBro service</li>
            <li>Improve app functionality and user experience</li>
            <li>Generate usage analytics and statistics</li>
            <li>Send important updates and notifications</li>
            <li>Provide customer support when requested</li>
            <li>Ensure app security and prevent fraud</li>
        </ul>

        <h2>4. Data Storage and Security</h2>
        <h3>Local Storage</h3>
        <p>Most of your data (tasks, notes, settings) is stored locally on your device and never leaves your device unless you explicitly enable cloud sync.</p>

        <h3>Cloud Backup (Optional)</h3>
        <p>If you enable cloud backup, your data is encrypted and stored securely in our cloud infrastructure.</p>

        <h3>Security Measures</h3>
        <ul>
            <li>End-to-end encryption for sensitive data</li>
            <li>Secure data transmission protocols</li>
            <li>Regular security audits and updates</li>
            <li>Limited access to personal data</li>
        </ul>

        <h2>5. Your Rights</h2>
        <p>You have the right to:</p>
        <ul>
            <li>Access your personal data</li>
            <li>Correct inaccurate information</li>
            <li>Delete your data (through app settings)</li>
            <li>Export your data (backup feature)</li>
            <li>Opt-out of analytics (through app settings)</li>
            <li>Withdraw consent for data processing</li>
        </ul>

        <h2>6. Third-Party Services</h2>
        <p>We may use third-party services for:</p>
        <ul>
            <li>Analytics and crash reporting</li>
            <li>Cloud storage and synchronization</li>
            <li>Push notifications</li>
        </ul>
        <p>These services have their own privacy policies and we encourage you to review them.</p>

        <h2>7. Children's Privacy</h2>
        <p>FocusBro is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us immediately.</p>

        <h2>8. Changes to This Privacy Policy</h2>
        <p>We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app and updating the "Last updated" date.</p>

        <div class="contact-info">
            <h2>9. Contact Us</h2>
            <p>If you have any questions about this Privacy Policy, please contact us:</p>
            <ul>
                <li><strong>Email:</strong> privacy@focusbro.app</li>
                <li><strong>Support:</strong> Through the app's Help & Support section</li>
                <li><strong>Response Time:</strong> We will respond to inquiries within 48 hours</li>
            </ul>
        </div>

        <div class="footer">
            <p><strong>FocusBro</strong> - Your Productivity Companion</p>
            <p>© ${DateTime.now().year} FocusBro. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
''';

  static String get termsOfServiceHtml => '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FocusBro Terms of Service</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
            background-color: #fff;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            color: #2196F3;
            border-bottom: 3px solid #2196F3;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        h2 {
            color: #1976D2;
            margin-top: 30px;
            margin-bottom: 15px;
        }
        h3 {
            color: #1565C0;
            margin-top: 25px;
            margin-bottom: 10px;
        }
        .last-updated {
            background-color: #E3F2FD;
            padding: 10px;
            border-radius: 8px;
            margin-bottom: 30px;
            font-size: 14px;
            color: #1976D2;
        }
        .highlight {
            background-color: #FFF3E0;
            padding: 15px;
            border-left: 4px solid #FF9800;
            margin: 20px 0;
        }
        ul {
            padding-left: 20px;
        }
        li {
            margin-bottom: 8px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            text-align: center;
            color: #666;
            font-size: 14px;
        }
        .contact-info {
            background-color: #F5F5F5;
            padding: 20px;
            border-radius: 8px;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚖️ FocusBro Terms of Service</h1>
        
        <div class="last-updated">
            <strong>Last updated:</strong> ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
        </div>

        <div class="highlight">
            <strong>Fair and Transparent Terms:</strong> These terms are designed to protect both users and developers while ensuring a great experience for everyone.
        </div>

        <h2>1. Agreement to Terms</h2>
        <p>By downloading, installing, or using the FocusBro mobile application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our app.</p>

        <h2>2. Description of Service</h2>
        <p>FocusBro is a productivity application that provides:</p>
        <ul>
            <li>Pomodoro timer functionality with customizable sessions</li>
            <li>Task and agenda management with priorities and categories</li>
            <li>Note-taking capabilities with rich text editing</li>
            <li>PDF reader with annotation and bookmark features</li>
            <li>Focus mode features for distraction blocking</li>
            <li>Music and ambient sound integration</li>
            <li>Analytics and progress tracking</li>
            <li>Cloud synchronization (optional)</li>
        </ul>

        <h2>3. User Responsibilities</h2>
        <p>As a user of FocusBro, you agree to:</p>
        <ul>
            <li>Use the app for lawful purposes only</li>
            <li>Not attempt to reverse engineer or modify the app</li>
            <li>Not share your account credentials with others</li>
            <li>Respect intellectual property rights</li>
            <li>Provide accurate information when required</li>
            <li>Keep your account information secure</li>
            <li>Report any security vulnerabilities responsibly</li>
        </ul>

        <h2>4. Acceptable Use Policy</h2>
        <p>You may not use FocusBro to:</p>
        <ul>
            <li>Violate any applicable laws or regulations</li>
            <li>Infringe on others' intellectual property rights</li>
            <li>Transmit harmful or malicious content</li>
            <li>Attempt to gain unauthorized access to our systems</li>
            <li>Use the app for commercial purposes without permission</li>
            <li>Interfere with other users' experience</li>
            <li>Distribute spam or unwanted communications</li>
        </ul>

        <h2>5. Intellectual Property Rights</h2>
        <ul>
            <li>FocusBro and all related content are owned by us or our licensors</li>
            <li>You are granted a limited, non-exclusive license to use the app</li>
            <li>You may not copy, modify, or distribute the app without permission</li>
            <li>All trademarks and logos are the property of their respective owners</li>
            <li>User-generated content remains your property</li>
        </ul>

        <h2>6. Privacy and Data Protection</h2>
        <ul>
            <li>Your privacy is important to us</li>
            <li>Please review our Privacy Policy for details on data collection</li>
            <li>You retain ownership of your personal data</li>
            <li>We implement security measures to protect your information</li>
            <li>You can delete your data at any time</li>
        </ul>

        <h2>7. Disclaimers and Limitations</h2>
        <ul>
            <li>FocusBro is provided "as is" without warranties</li>
            <li>We do not guarantee uninterrupted or error-free service</li>
            <li>We are not liable for any indirect or consequential damages</li>
            <li>Your use of the app is at your own risk</li>
            <li>We are not responsible for third-party content or services</li>
        </ul>

        <h2>8. App Updates and Changes</h2>
        <ul>
            <li>We may update the app to improve functionality</li>
            <li>We may modify these terms with notice to users</li>
            <li>Continued use after changes constitutes acceptance</li>
            <li>We reserve the right to discontinue features</li>
            <li>Critical security updates may be mandatory</li>
        </ul>

        <h2>9. Termination</h2>
        <ul>
            <li>You may stop using FocusBro at any time</li>
            <li>We may terminate access for violations of these terms</li>
            <li>Upon termination, your license to use the app ends</li>
            <li>Data deletion procedures are outlined in our Privacy Policy</li>
            <li>Certain provisions survive termination</li>
        </ul>

        <h2>10. Governing Law</h2>
        <p>These terms are governed by the laws of the jurisdiction where our company is registered. Any disputes will be resolved through binding arbitration.</p>

        <div class="contact-info">
            <h2>11. Contact Information</h2>
            <p>For questions about these Terms of Service:</p>
            <ul>
                <li><strong>Email:</strong> legal@focusbro.app</li>
                <li><strong>Support:</strong> Through the app's Help & Support section</li>
                <li><strong>Response Time:</strong> We will respond to inquiries within 48 hours</li>
            </ul>
        </div>

        <div class="footer">
            <p><strong>FocusBro</strong> - Your Productivity Companion</p>
            <p>© ${DateTime.now().year} FocusBro. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
''';
}
