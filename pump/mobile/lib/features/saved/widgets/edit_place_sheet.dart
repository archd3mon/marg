import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models/saved_item.dart';
import '../../../app/app_state.dart';

class EditPlaceSheet extends ConsumerStatefulWidget {
  final SavedPlace place;
  const EditPlaceSheet({super.key, required this.place});

  static Future<void> show(BuildContext context, SavedPlace place) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditPlaceSheet(place: place),
    );
  }

  @override
  ConsumerState<EditPlaceSheet> createState() => _EditPlaceSheetState();
}

class _EditPlaceSheetState extends ConsumerState<EditPlaceSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  double _lat = 18.5074, _lng = 73.8077;

  static const _puneCoords = {
    'Kothrud': (18.5074, 73.8077),
    'Viman Nagar': (18.5679, 73.9143),
    'Deccan': (18.5182, 73.8413),
    'Shivajinagar': (18.5308, 73.8475),
    'Baner': (18.5590, 73.7868),
    'Hinjawadi': (18.5913, 73.7389),
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place.name);
    _locationController = TextEditingController(text: widget.place.locationName);
    _lat = widget.place.lat;
    _lng = widget.place.lng;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final loc = _locationController.text.trim();
    if (name.isEmpty || loc.isEmpty) return;

    ref.read(savedPlacesProvider.notifier).updatePlace(SavedPlace(
      id: widget.place.id,
      name: name,
      locationName: loc,
      lat: _lat,
      lng: _lng,
      type: widget.place.type,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, Sp.x5 + bottomInset),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(color: c.label3, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: Sp.x3),
          Text('Edit ${widget.place.name}', style: MargText.title3.copyWith(color: c.label)),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _nameController,
            style: MargText.body.copyWith(color: c.label),
            decoration: InputDecoration(
              labelText: 'Place Label',
              labelStyle: MargText.footnote.copyWith(color: c.label2),
              filled: true,
              fillColor: c.fill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _locationController,
            style: MargText.body.copyWith(color: c.label),
            decoration: InputDecoration(
              labelText: 'Location Name',
              labelStyle: MargText.footnote.copyWith(color: c.label2),
              filled: true,
              fillColor: c.fill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: Sp.x2),
          Wrap(
            spacing: Sp.x2,
            children: _puneCoords.keys.map((loc) {
              final isSelected = _locationController.text == loc;
              return ChoiceChip(
                label: Text(loc, style: MargText.caption.copyWith(color: isSelected ? Colors.white : c.label)),
                selected: isSelected,
                selectedColor: c.blue,
                backgroundColor: c.fill,
                onSelected: (_) => setState(() {
                  _locationController.text = loc;
                  _lat = _puneCoords[loc]!.$1;
                  _lng = _puneCoords[loc]!.$2;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: Sp.x4),
          PrimaryButton(label: 'Save Place', onPressed: _save),
        ],
      ),
    );
  }
}
