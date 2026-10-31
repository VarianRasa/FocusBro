import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Enhanced WebView Screen for displaying legal documents and web content
class EnhancedWebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final String? fallbackContent;
  final bool showRefreshButton;
  final bool showShareButton;

  const EnhancedWebViewScreen({
    super.key,
    required this.title,
    required this.url,
    this.fallbackContent,
    this.showRefreshButton = true,
    this.showShareButton = false,
  });

  @override
  State<EnhancedWebViewScreen> createState() => _EnhancedWebViewScreenState();
}

class _EnhancedWebViewScreenState extends State<EnhancedWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description;
            });
          },
        ),
      );

    // Load the URL or fallback content
    if (widget.url.startsWith('http')) {
      _controller.loadRequest(Uri.parse(widget.url));
    } else {
      // Load local HTML content
      _controller
          .loadHtmlString(widget.fallbackContent ?? _getDefaultContent());
    }
  }

  String _getDefaultContent() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${widget.title}</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                margin: 20px;
                color: #333;
                background-color: #fff;
            }
            h1 {
                color: #2196F3;
                border-bottom: 2px solid #2196F3;
                padding-bottom: 10px;
            }
            h2 {
                color: #1976D2;
                margin-top: 30px;
            }
            .container {
                max-width: 800px;
                margin: 0 auto;
            }
            .footer {
                margin-top: 40px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                text-align: center;
                color: #666;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>${widget.title}</h1>
            <p>Content is being loaded...</p>
            <div class="footer">
                <p>FocusBro - Your Productivity Companion</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  void _refresh() {
    _controller.reload();
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Future<void> _sharePage() async {
    try {
      final pageUrl = await _controller.currentUrl() ?? widget.url;
      await Share.share('$pageUrl', subject: widget.title);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share page: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          if (widget.showRefreshButton)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: 'Refresh',
            ),
          if (widget.showShareButton)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePage,
              tooltip: 'Share',
            ),
        ],
      ),
      body: Column(
        children: [
          // Loading Progress Bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),

          // WebView Content
          Expanded(
            child: _hasError
                ? _buildErrorView(theme)
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Content',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
            if (widget.fallbackContent != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _controller.loadHtmlString(widget.fallbackContent!);
                },
                child: const Text('View Offline Content'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
