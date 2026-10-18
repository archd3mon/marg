import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app_state.dart';
import '../../../data/models/place.dart';
import '../../../data/api_client.dart';
import '../../../shared/widgets/tile_icon.dart';
import '../../../theme/marg_tokens.dart';

class PlaceSearchSheet extends ConsumerStatefulWidget {
  final bool isSelectingFrom;
  final ValueChanged<Place> onPlaceSelected;
  final VoidCallback onPickOnMap;

  const PlaceSearchSheet({
    super.key,
    required this.isSelectingFrom,
    required this.onPlaceSelected,
    required this.onPickOnMap,
  });

  @override
  ConsumerState<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<PlaceSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  static final Map<String, List<Place>> _sessionCache = {};

  Timer? _debounceTimer;
  List<Place> _results = [];
  bool _isSearching = false;
  String _activeQuery = '';
  String? _errorMessage;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _activeQuery = '';
        _results = [];
        _errorMessage = null;
        _isSearching = false;
      });
      return;
    }

    final cacheKey = trimmed.toLowerCase();
    if (_sessionCache.containsKey(cacheKey)) {
      setState(() {
        _activeQuery = trimmed;
        _results = _sessionCache[cacheKey]!;
        _errorMessage = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _activeQuery = trimmed;
      _errorMessage = null;
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final repo = ref.read(transitRepositoryProvider);
        final places = await repo.searchGeocode(trimmed);
        _sessionCache[cacheKey] = places;
        if (mounted && _activeQuery == trimmed) {
          setState(() {
            _results = places;
            _errorMessage = null;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted && _activeQuery == trimmed) {
          setState(() {
            _results = [];
            _errorMessage = e is ApiOfflineException
                ? 'Network connection unavailable'
                : 'Unable to search places';
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectPlace(Place place) {
    HapticFeedback.selectionClick();
    ref.read(storageServiceProvider).addRecentSearch(place);
    widget.onPlaceSelected(place);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final recents = ref.watch(storageServiceProvider).getRecentSearches();

    return Glass(
      radius: Rad.sheet,
      topOnly: true,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, 0),
          child: Column(
            children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: c.label3,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),

            // Header title & close
            Row(
              children: [
                Text(
                  widget.isSelectingFrom ? 'Choose Starting Point' : 'Choose Destination',
                  style: MargText.headline.copyWith(color: c.label),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: c.label2, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Sp.x2),

            // Search input field
            Container(
              decoration: BoxDecoration(
                color: c.fill,
                borderRadius: BorderRadius.circular(Rad.md),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: MargText.body.copyWith(color: c.label),
                decoration: InputDecoration(
                  hintText: widget.isSelectingFrom ? 'Search origin in Pune...' : 'Search destination in Pune...',
                  hintStyle: MargText.body.copyWith(color: c.label2),
                  prefixIcon: Icon(Icons.search_rounded, color: c.label2, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.cancel_rounded, color: c.label3, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x3),
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),

            // Actions row: Current Location & Pick on Map
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _selectPlace(const Place(
                        id: 'curr_loc',
                        name: 'Current Location',
                        displayName: 'Pune, Maharashtra',
                        lat: 18.5074,
                        lng: 73.8077,
                        type: 'poi',
                      ));
                    },
                    borderRadius: BorderRadius.circular(Rad.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: Sp.x2, horizontal: Sp.x2),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(Rad.sm),
                        border: Border.all(color: c.separator, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.my_location_rounded, color: c.blue, size: 16),
                          const SizedBox(width: Sp.x1),
                          Flexible(
                            child: Text(
                              'Current Location',
                              style: MargText.caption.copyWith(
                                color: c.blue,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Sp.x2),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      widget.onPickOnMap();
                    },
                    borderRadius: BorderRadius.circular(Rad.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: Sp.x2, horizontal: Sp.x2),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(Rad.sm),
                        border: Border.all(color: c.separator, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pin_drop_rounded, color: c.red, size: 16),
                          const SizedBox(width: Sp.x1),
                          Flexible(
                            child: Text(
                              'Pick on Map',
                              style: MargText.caption.copyWith(
                                color: c.label,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x3),

            // Content: Results or Recents
            Expanded(
              child: _buildBody(context, c, recents),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildBody(BuildContext context, MargColors c, List<Place> recents) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator.adaptive(strokeWidth: 2.5),
            const SizedBox(height: Sp.x2),
            Text('Searching Pune places...', style: MargText.footnote.copyWith(color: c.label2)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: c.orange),
            const SizedBox(height: Sp.x2),
            Text(
              _errorMessage!,
              style: MargText.subhead.copyWith(color: c.label2),
            ),
          ],
        ),
      );
    }

    if (_activeQuery.isNotEmpty) {
      if (_results.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: c.label3),
              const SizedBox(height: Sp.x2),
              Text(
                'No places found for "$_activeQuery"',
                style: MargText.subhead.copyWith(color: c.label2),
              ),
              const SizedBox(height: Sp.x1),
              Text(
                'Try searching for an area, stop or landmark in Pune',
                style: MargText.caption.copyWith(color: c.label3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (context, index) => Divider(color: c.separator, height: 0.5, indent: 48),
        itemBuilder: (ctx, i) {
          final place = _results[i];
          final isStop = place.type == 'stop';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: TileIcon(
              icon: isStop ? Icons.directions_bus_rounded : Icons.location_on_rounded,
              color: isStop ? TileColor.blue : TileColor.gray,
              size: 32,
              iconSize: 16,
            ),
            title: Text(place.name, style: MargText.body.copyWith(color: c.label)),
            subtitle: Text(place.displayName, style: MargText.caption.copyWith(color: c.label2)),
            onTap: () => _selectPlace(place),
          );
        },
      );
    }

    // Default: Recent searches
    return ListView(
      children: [
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x2),
            child: Text(
              'RECENT SEARCHES',
              style: MargText.caption.copyWith(
                color: c.label2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final place in recents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const TileIcon(
                icon: Icons.access_time_rounded,
                color: TileColor.gray,
                size: 32,
                iconSize: 16,
              ),
              title: Text(place.name, style: MargText.body.copyWith(color: c.label)),
              subtitle: Text(place.displayName, style: MargText.caption.copyWith(color: c.label2)),
              onTap: () => _selectPlace(place),
            ),
        ],
      ],
    );
  }
}
