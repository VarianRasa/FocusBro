import 'dart:async';
import 'package:flutter/material.dart';

/// Chart data point for analytics
class ChartDataPoint {
  final String label;
  final double value;
  final Color? color;

  ChartDataPoint(this.label, this.value, {this.color});
}

/// Lazy loading utility for better performance
class LazyLoader<T> {
  final Future<T> Function() _loader;
  final Duration? _cacheDuration;

  T? _cachedData;
  DateTime? _cacheTime;
  Future<T>? _loadingFuture;

  LazyLoader(this._loader, {Duration? cacheDuration})
      : _cacheDuration = cacheDuration;

  /// Get data with lazy loading
  Future<T> get() async {
    // Return cached data if valid
    if (_cachedData != null && _isCacheValid()) {
      return _cachedData!;
    }

    // Return existing loading future if already loading
    if (_loadingFuture != null) {
      return _loadingFuture!;
    }

    // Start loading
    _loadingFuture = _loader();

    try {
      _cachedData = await _loadingFuture!;
      _cacheTime = DateTime.now();
      return _cachedData!;
    } finally {
      _loadingFuture = null;
    }
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (_cacheDuration == null || _cacheTime == null) return true;
    return DateTime.now().difference(_cacheTime!) < _cacheDuration!;
  }

  /// Invalidate cache
  void invalidate() {
    _cachedData = null;
    _cacheTime = null;
  }

  /// Check if data is cached
  bool get isCached => _cachedData != null && _isCacheValid();

  /// Check if currently loading
  bool get isLoading => _loadingFuture != null;
}

/// Lazy loading widget for UI components
class LazyLoadingWidget<T> extends StatefulWidget {
  final Future<T> Function() loader;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Duration? cacheDuration;
  final bool autoLoad;

  const LazyLoadingWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.cacheDuration,
    this.autoLoad = true,
  });

  @override
  State<LazyLoadingWidget<T>> createState() => _LazyLoadingWidgetState<T>();
}

class _LazyLoadingWidgetState<T> extends State<LazyLoadingWidget<T>> {
  late LazyLoader<T> _lazyLoader;
  T? _data;
  Object? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lazyLoader =
        LazyLoader<T>(widget.loader, cacheDuration: widget.cacheDuration);

    if (widget.autoLoad) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _lazyLoader.get();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _lazyLoader.invalidate();
                    _loadData();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    if (_isLoading || _data == null) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }

    return widget.builder(context, _data!);
  }

  /// Manually trigger reload
  void reload() {
    _lazyLoader.invalidate();
    _loadData();
  }
}

/// Lazy loading list for large datasets
class LazyLoadingList<T> extends StatefulWidget {
  final Future<List<T>> Function(int offset, int limit) loader;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final int pageSize;
  final ScrollController? scrollController;

  const LazyLoadingList({
    super.key,
    required this.loader,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.pageSize = 20,
    this.scrollController,
  });

  @override
  State<LazyLoadingList<T>> createState() => _LazyLoadingListState<T>();
}

class _LazyLoadingListState<T> extends State<LazyLoadingList<T>> {
  final List<T> _items = [];
  late ScrollController _scrollController;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newItems = await widget.loader(_items.length, widget.pageSize);

      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _hasMore = newItems.length == widget.pageSize;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return widget.errorBuilder?.call(context, _error!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    if (_items.isEmpty && _isLoading) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return widget.emptyBuilder?.call(context) ??
          const Center(
            child: Text('No items found'),
          );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }
}

/// Lazy loading grid for large datasets
class LazyLoadingGrid<T> extends StatefulWidget {
  final Future<List<T>> Function(int offset, int limit) loader;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final int pageSize;
  final ScrollController? scrollController;

  const LazyLoadingGrid({
    super.key,
    required this.loader,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.pageSize = 20,
    this.scrollController,
  });

  @override
  State<LazyLoadingGrid<T>> createState() => _LazyLoadingGridState<T>();
}

class _LazyLoadingGridState<T> extends State<LazyLoadingGrid<T>> {
  final List<T> _items = [];
  late ScrollController _scrollController;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newItems = await widget.loader(_items.length, widget.pageSize);

      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _hasMore = newItems.length == widget.pageSize;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return widget.errorBuilder?.call(context, _error!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    if (_items.isEmpty && _isLoading) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return widget.emptyBuilder?.call(context) ??
          const Center(
            child: Text('No items found'),
          );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(child: CircularProgressIndicator());
          }

          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }
}
