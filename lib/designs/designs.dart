import 'all_prayers_design.dart';
import 'classic_design.dart';
import 'display_design.dart';
import 'emerald_design.dart';
import 'focus_design.dart';
import 'list_design.dart';
import 'ring_design.dart';

/// Every design, in the order shown in Settings. Add new designs here.
const List<DisplayDesign> kDesigns = [
  classicDesign,
  allPrayersDesign,
  listDesign,
  focusDesign,
  ringDesign,
  emeraldDesign,
];

const kDefaultDesignId = 'classic';

/// The design with [id]; an unknown or removed id falls back to the default so a saved
/// setting can never leave the screen blank.
DisplayDesign designById(String id) => kDesigns.firstWhere(
      (d) => d.id == id,
      orElse: () => kDesigns.firstWhere((d) => d.id == kDefaultDesignId),
    );
