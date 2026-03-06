import 'package:ecoquest/game/level3/sorting_facility_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CRAFTING WORKSHOP SCREEN
//  Pure Flutter — zero Flame, zero image assets.
//  All data read from SortingResult.current (written by SortingFacilityScreen).
//  Each waste category shows a bin + list of craftable products with emojis,
//  descriptions, required item counts, and educational facts.
// ══════════════════════════════════════════════════════════════════════════════

class CraftingWorkshopScreen extends StatefulWidget {
  const CraftingWorkshopScreen({super.key});

  @override
  State<CraftingWorkshopScreen> createState() => _CraftingWorkshopScreenState();
}

class _CraftingWorkshopScreenState extends State<CraftingWorkshopScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _headerAnim;
  late final AnimationController _shimmerAnim;
  late final AnimationController _staggerAnim;

  // ── Screen state ──────────────────────────────────────────────────────────
  int _selectedIndex  = 0;
  int _craftedCount   = 0;
  int _ecoCreativity  = 0;
  final Set<String> _crafted = {};   // "categoryKey::productName"

  // ── Resolved material counts ──────────────────────────────────────────────
  late final int _plastic;
  late final int _metal;
  late final int _organic;
  late final int _glass;
  late final int _metallic;
  late final int _hazardous;
  late final int _ecoPoints;

  late final List<_WasteCategory> _categories;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _bg      = Color(0xFF070D1A);
  static const _divider = Color(0xFF1C2E45);

  @override
  void initState() {
    super.initState();

    // Read from global static holder written by SortingFacilityScreen
    final r  = SortingResult.current;
    _plastic   = r?.plastic   ?? 0;
    _metal     = r?.metal     ?? 0;
    _organic   = r?.organic   ?? 0;
    _glass     = r?.glass     ?? 0;
    _metallic  = r?.metallic  ?? 0;
    _hazardous = r?.hazardous ?? 0;
    _ecoPoints = r?.ecoPoints ?? 0;

    _buildCatalogue();

    _headerAnim  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _shimmerAnim = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
    _staggerAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _shimmerAnim.dispose();
    _staggerAnim.dispose();
    super.dispose();
  }

  // ── Catalogue ─────────────────────────────────────────────────────────────
  void _buildCatalogue() {
    _categories = [

      // ── PLASTIC ───────────────────────────────────────────────────────────
      _WasteCategory(
        key:      'plastic',
        label:    'Plastic',
        emoji:    '🧴',
        color:    const Color(0xFF1E88E5),
        shade:    const Color(0xFF0D47A1),
        count:    _plastic,
        binNote:  'PET bottles · HDPE containers · bags · cups · packaging',
        products: [
          _Product('🧵', 'Eco Yarn',
              'Shredded & melt-spun into polyester thread for weaving fabric.',
              3, 30,
              '5 plastic bottles yield enough yarn to make a full T-shirt.'),
          _Product('🪑', 'Garden Chair',
              'Fused HDPE pellets moulded into weather-proof outdoor furniture.',
              8, 55,
              'Recycled plastic furniture lasts 50+ years with zero maintenance.'),
          _Product('🌱', 'Seedling Pot',
              'Trimmed bottles repurposed as biodegradable nursery pots.',
              2, 20,
              'Plastic pots cut nursery costs by 70 % on smallholder farms.'),
          _Product('🧱', 'Eco-Brick',
              'Bottles tightly stuffed with soft plastic to form building blocks.',
              5, 40,
              'An eco-brick school in Uganda houses 60 students at 80 % less cost.'),
          _Product('🎒', 'Woven Bag',
              'Plastic strips braided into sturdy, reusable carry bags.',
              4, 35,
              'One woven bag replaces 500 single-use plastic bags over its life.'),
        ],
      ),

      // ── ORGANIC ───────────────────────────────────────────────────────────
      _WasteCategory(
        key:      'organic',
        label:    'Organic',
        emoji:    '🍌',
        color:    const Color(0xFF43A047),
        shade:    const Color(0xFF1B5E20),
        count:    _organic,
        binNote:  'Food scraps · peels · garden waste · cloth · paper · natural fibres',
        products: [
          _Product('🌿', 'Compost Manure',
              'Aerobic decomposition turns food waste into nutrient-rich soil.',
              2, 25,
              'Compost can double crop yields at a fraction of chemical fertiliser cost.'),
          _Product('🔥', 'Biogas',
              'Anaerobic digestion releases methane captured for cooking & electricity.',
              5, 50,
              'A family biodigester fed with kitchen waste fully replaces LPG gas.'),
          _Product('🧴', 'Liquid Fertiliser',
              'Fermented plant juice — a potent foliar spray for crops.',
              4, 35,
              'FPJ boosts plant immunity and reduces pesticide use by 60 %.'),
          _Product('📄', 'Recycled Paper',
              'Plant fibre pulped & pressed into new sheets, reducing deforestation.',
              3, 28,
              'Recycling one tonne of paper saves 17 trees and 7,000 gallons of water.'),
          _Product('🕯️', 'Organic Candle',
              'Rendered organic wax shaped into slow-burning clean candles.',
              3, 30,
              'Beeswax candles emit negative ions that naturally purify indoor air.'),
        ],
      ),

      // ── GLASS ─────────────────────────────────────────────────────────────
      _WasteCategory(
        key:      'glass',
        label:    'Glass',
        emoji:    '🍶',
        color:    const Color(0xFF00ACC1),
        shade:    const Color(0xFF006064),
        count:    _glass,
        binNote:  'Bottles · jars · broken panes · glass containers',
        products: [
          _Product('🏮', 'Bottle Lantern',
              'Whole bottles fitted with LED filaments as solar decorative lights.',
              2, 28,
              'Glass lanterns diffuse light 40 % better than plastic equivalents.'),
          _Product('🎨', 'Mosaic Tiles',
              'Broken glass smoothed & arranged into colourful decorative surface tiles.',
              3, 35,
              'Glass mosaic art has existed since ancient Rome — glass never truly degrades.'),
          _Product('🌸', 'Glass Vase',
              'Bottles cut, polished & fused — zero raw material needed.',
              2, 22,
              'Recycled glass melts at a lower temperature, saving 30 % energy.'),
          _Product('🪟', 'Insulating Wool',
              'Cullet melted and spun into fibreglass insulation for walls & roofing.',
              6, 55,
              'Fibreglass from recycled glass cuts home energy bills by 30 %.'),
          _Product('🏗️', 'Glass Paving',
              'Crushed cullet mixed into asphalt or concrete for road surfacing.',
              8, 60,
              'Glass-aggregate asphalt is 20 % stronger and improves night visibility.'),
        ],
      ),

      // ── METALLIC ──────────────────────────────────────────────────────────
      _WasteCategory(
        key:      'metallic',
        label:    'Metal',
        emoji:    '🔩',
        color:    const Color(0xFF78909C),
        shade:    const Color(0xFF263238),
        count:    _metal + _metallic,
        binNote:  'Tin cans · bolts · gears · buckets · wrenches · scrap steel',
        products: [
          _Product('🍳', 'Cooking Pot',
              'Scrap metal smelted and cast into durable cookware for households.',
              4, 40,
              'Recycled aluminium uses only 5 % of the energy to produce virgin metal.'),
          _Product('🌱', 'Drip Irrigator',
              'Tin cans perforated and strung as low-cost drip irrigation.',
              3, 30,
              'Tin-can drip systems cut water use by 50 % on Kenyan vegetable farms.'),
          _Product('🎷', 'Tin Instrument',
              'Cans and pipes shaped into percussion or wind instruments.',
              5, 45,
              'The mbira, a Zimbabwean thumb piano, has been crafted from scrap metal for centuries.'),
          _Product('🔑', 'Craft Jewellery',
              'Flattened cans and wire shaped into earrings, bangles & pendants.',
              2, 25,
              'Upcycled metal jewellery is a growing export industry in Kenya & Ethiopia.'),
          _Product('🏗️', 'Rebar / Rods',
              'Steel scrap re-rolled into construction reinforcement bars.',
              8, 60,
              'Every tonne of recycled steel saves 1.5 tonnes of CO₂ vs virgin steel.'),
        ],
      ),

      // ── E-WASTE ───────────────────────────────────────────────────────────
      _WasteCategory(
        key:      'ewaste',
        label:    'E-Waste',
        emoji:    '📱',
        color:    const Color(0xFFF57C00),
        shade:    const Color(0xFFBF360C),
        count:    _hazardous,
        binNote:  'Old phones · batteries · bulbs · circuit boards · cables',
        products: [
          _Product('💡', 'Solar Lamp Kit',
              'Salvaged LED components & cells reassembled into solar lamps.',
              3, 45,
              'Refurbished solar lamps replace kerosene in 500 M+ off-grid homes.'),
          _Product('🔋', 'Battery Pack',
              'Functional cells harvested from depleted packs reconfigured into power banks.',
              4, 50,
              'Up to 80 % of lithium-ion cells are still usable when batteries seem "dead".'),
          _Product('🏅', 'Recovered Gold',
              'PCBs dissolved in acid baths to extract precious metals — gold, silver, palladium.',
              6, 70,
              'One tonne of circuit boards contains 100× more gold than one tonne of gold ore.'),
          _Product('🎨', 'Circuit Art',
              'Desoldered boards arranged into decorative wall panels & frames.',
              2, 20,
              'E-waste art raises awareness — and sells for up to \$2,000 per piece at galleries.'),
        ],
      ),
    ];
  }

  // ── Craft action ──────────────────────────────────────────────────────────
  void _craft(_WasteCategory cat, _Product p) {
    final key = '${cat.key}::${p.name}';
    if (_crafted.contains(key) || cat.count < p.minItems) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _crafted.add(key);
      _craftedCount++;
      _ecoCreativity += p.xp;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: cat.color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      content: Row(children: [
        Text(p.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${p.name} crafted!',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Colors.white)),
            Text('+${p.xp} Eco-Creativity XP',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        )),
      ]),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final mobile   = mq.size.width < 640;
    final cat      = _categories[_selectedIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(children: [
            _Header(
              anim:     _headerAnim,
              shimmer:  _shimmerAnim,
              xp:       _ecoCreativity,
              onBack:   () => Navigator.of(context).pop(),
              mobile:   mobile,
            ),
            _CategoryRail(
              categories:    _categories,
              selectedIndex: _selectedIndex,
              onSelect: (i) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedIndex = i;
                  _staggerAnim.forward(from: 0);
                });
              },
              mobile: mobile,
            ),
            const Divider(height: 1, color: _divider),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0.04, 0), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: _CategoryPanel(
                  key:         ValueKey(cat.key),
                  cat:         cat,
                  crafted:     _crafted,
                  staggerAnim: _staggerAnim,
                  mobile:      mobile,
                  onCraft:     (p) => _craft(cat, p),
                ),
              ),
            ),
            _FooterBar(
              totalItems:    _categories.fold(0, (s, c) => s + c.count),
              craftedCount:  _craftedCount,
              ecoPoints:     _ecoPoints,
              ecoCreativity: _ecoCreativity,
              mobile:        mobile,
              onFinish:      _showFinishDialog,
            ),
          ]),
        ),
      ),
    );
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      builder: (_) => _FinishDialog(
        crafted:      _craftedCount,
        ecoCreativity: _ecoCreativity,
        ecoPoints:    _ecoPoints,
        onClose: () {
          Navigator.of(context).pop(); // dialog
          Navigator.of(context).pop(); // workshop
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HEADER
// ════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final AnimationController anim, shimmer;
  final int xp;
  final VoidCallback onBack;
  final bool mobile;

  const _Header({
    required this.anim, required this.shimmer, required this.xp,
    required this.onBack, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - t)),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 14 : 22, vertical: 13),
              decoration: const BoxDecoration(
                color: Color(0xFF0C1525),
                border: Border(bottom: BorderSide(color: Color(0xFF1C2E45))),
              ),
              child: Row(children: [
                // Back
                _IconBtn(icon: Icons.arrow_back_ios_new_rounded,
                    size: 15, onTap: onBack),
                const SizedBox(width: 12),
                // Title
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('♻️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('Crafting Workshop',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: mobile ? 17 : 21,
                            letterSpacing: 0.5,
                          )),
                    ]),
                    const SizedBox(height: 1),
                    Text('Turn sorted waste into useful products',
                        style: const TextStyle(
                            color: Color(0xFF5A7A99), fontSize: 11)),
                  ],
                )),
                // XP badge
                AnimatedBuilder(
                  animation: shimmer,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color.lerp(const Color(0xFF2E7D32),
                            const Color(0xFF66BB6A), shimmer.value)!,
                        const Color(0xFF388E3C),
                      ]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF43A047)
                              .withValues(alpha: 0.25 + shimmer.value * 0.2),
                          blurRadius: 10)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('⚡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text('$xp XP',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CATEGORY RAIL  — horizontal bin tabs
// ════════════════════════════════════════════════════════════════════════════
class _CategoryRail extends StatelessWidget {
  final List<_WasteCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool mobile;

  const _CategoryRail({
    required this.categories, required this.selectedIndex,
    required this.onSelect, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 90 : 102,
      color: const Color(0xFF0C1525),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat  = categories[i];
          final sel  = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 9),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: sel
                    ? cat.color.withValues(alpha: 0.15)
                    : const Color(0xFF0E1C2E),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: sel ? cat.color : Colors.white.withValues(alpha: 0.08),
                  width: sel ? 1.8 : 1,
                ),
                boxShadow: sel ? [BoxShadow(
                    color: cat.color.withValues(alpha: 0.2),
                    blurRadius: 10)] : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.emoji,
                      style: TextStyle(fontSize: mobile ? 22 : 26)),
                  const SizedBox(height: 3),
                  Text(cat.label,
                      style: TextStyle(
                        color: sel ? cat.color : const Color(0xFF4A6A88),
                        fontSize: 10,
                        fontWeight: sel
                            ? FontWeight.bold : FontWeight.normal,
                      )),
                  const SizedBox(height: 2),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: cat.count > 0
                          ? cat.color.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat.count > 0 ? '${cat.count}×' : '—',
                      style: TextStyle(
                        color: cat.count > 0
                            ? cat.color
                            : const Color(0xFF2A4A66),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CATEGORY PANEL — bin card + product list + edu callout
// ════════════════════════════════════════════════════════════════════════════
class _CategoryPanel extends StatelessWidget {
  final _WasteCategory cat;
  final Set<String> crafted;
  final AnimationController staggerAnim;
  final bool mobile;
  final ValueChanged<_Product> onCraft;

  const _CategoryPanel({
    super.key,
    required this.cat, required this.crafted, required this.staggerAnim,
    required this.mobile, required this.onCraft,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          mobile ? 13 : 18, 14, mobile ? 13 : 18, 16),
      children: [
        _BinCard(cat: cat, mobile: mobile),
        const SizedBox(height: 18),
        // Section header
        Row(children: [
          Container(width: 3, height: 17, color: cat.color,
              margin: const EdgeInsets.only(right: 10)),
          Text('Recyclable Products',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: mobile ? 14 : 16)),
          const Spacer(),
          Text('${cat.products.length} recipes',
              style: TextStyle(color: cat.color, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        // Product cards
        ...cat.products.asMap().entries.map((e) =>
          _ProductCard(
            cat:         cat,
            product:     e.value,
            idx:         e.key,
            isCrafted:   crafted.contains('${cat.key}::${e.value.name}'),
            staggerAnim: staggerAnim,
            mobile:      mobile,
            onCraft:     () => onCraft(e.value),
          ),
        ),
        const SizedBox(height: 6),
        _EduCallout(cat: cat),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BIN CARD — top panel showing the bin and item count
// ════════════════════════════════════════════════════════════════════════════
class _BinCard extends StatelessWidget {
  final _WasteCategory cat;
  final bool mobile;
  const _BinCard({required this.cat, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final empty = cat.count == 0;
    final fill  = (cat.count / 20.0).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(mobile ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: empty
              ? [const Color(0xFF111E2E), const Color(0xFF0C1525)]
              : [cat.shade.withValues(alpha: 0.6),
                 cat.color.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: empty
              ? Colors.white.withValues(alpha: 0.07)
              : cat.color.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: empty ? [] : [
          BoxShadow(color: cat.color.withValues(alpha: 0.10),
              blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Bin visual
        Container(
          width: mobile ? 62 : 76,
          height: mobile ? 72 : 88,
          decoration: BoxDecoration(
            color: empty
                ? Colors.white.withValues(alpha: 0.04)
                : cat.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: empty ? Colors.white12
                    : cat.color.withValues(alpha: 0.32)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(cat.emoji,
                  style: TextStyle(fontSize: mobile ? 26 : 32)),
              const SizedBox(height: 3),
              Text('BIN', style: TextStyle(
                color: empty ? Colors.white12 : cat.color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              )),
            ],
          ),
        ),

        const SizedBox(width: 14),

        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + count badge
            Row(children: [
              Expanded(child: Text(cat.label,
                  style: TextStyle(
                    color: empty ? const Color(0xFF3A5A78) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: mobile ? 16 : 19,
                  ))),
              _CountBadge(count: cat.count, color: cat.color, empty: empty),
            ]),

            const SizedBox(height: 7),

            // Fill bar
            if (!empty) ...[
              Stack(children: [
                Container(height: 6, decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(height: 6, decoration: BoxDecoration(
                      color: cat.color,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [BoxShadow(
                          color: cat.color.withValues(alpha: 0.5),
                          blurRadius: 5)])),
                ),
              ]),
              const SizedBox(height: 8),
            ],

            // Bin description or empty-bin guidance
            Text(
              empty
                  ? '⚠️  No ${cat.label.toLowerCase()} items were sorted into '
                    'this bin. Play through the city collection phase and sort '
                    'more ${cat.label.toLowerCase()} items to unlock these '
                    'crafting recipes!'
                  : cat.binNote,
              style: TextStyle(
                color: empty
                    ? Colors.orange.withValues(alpha: 0.65)
                    : const Color(0xFF4A7095),
                fontSize: mobile ? 11 : 12,
                height: 1.45,
                fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PRODUCT CARD
// ════════════════════════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  final _WasteCategory     cat;
  final _Product           product;
  final int                idx;
  final bool               isCrafted;
  final AnimationController staggerAnim;
  final bool               mobile;
  final VoidCallback       onCraft;

  const _ProductCard({
    required this.cat, required this.product, required this.idx,
    required this.isCrafted, required this.staggerAnim,
    required this.mobile, required this.onCraft,
  });

  @override
  Widget build(BuildContext context) {
    final canCraft = !isCrafted && cat.count >= product.minItems;
    final shortage = product.minItems - cat.count;

    return AnimatedBuilder(
      animation: staggerAnim,
      builder: (_, child) {
        final delay = idx * 0.07;
        final raw   = ((staggerAnim.value - delay) / (1.0 - delay))
            .clamp(0.0, 1.0);
        final t     = Curves.easeOutBack.transform(raw).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: isCrafted
              ? cat.color.withValues(alpha: 0.10)
              : const Color(0xFF0E1C2E),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isCrafted
                ? cat.color.withValues(alpha: 0.55)
                : canCraft
                    ? cat.color.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
            width: isCrafted ? 1.4 : 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(mobile ? 11 : 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Emoji icon
              Container(
                width: mobile ? 46 : 54,
                height: mobile ? 46 : 54,
                decoration: BoxDecoration(
                  color: cat.color.withValues(
                      alpha: isCrafted ? 0.18 : 0.09),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: cat.color.withValues(alpha: isCrafted ? 0.55 : 0.18)),
                ),
                child: Center(child: Text(product.emoji,
                    style: TextStyle(fontSize: mobile ? 20 : 24))),
              ),

              const SizedBox(width: 11),

              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Name row
                  Row(children: [
                    Expanded(child: Text(product.name,
                        style: TextStyle(
                          color: isCrafted ? cat.color : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: mobile ? 13 : 14,
                        ))),
                    if (isCrafted)
                      _Chip(
                        label: '✓ Crafted',
                        color: cat.color,
                        faint: true,
                      ),
                  ]),

                  const SizedBox(height: 3),

                  // Description
                  Text(product.desc,
                      style: const TextStyle(
                          color: Color(0xFF4A7095),
                          fontSize: 11, height: 1.4)),

                  const SizedBox(height: 8),

                  // Fun fact (indented)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ',
                            style: TextStyle(fontSize: 11)),
                        Expanded(child: Text(product.fact,
                            style: TextStyle(
                              color: Colors.amber.withValues(alpha: 0.7),
                              fontSize: 10,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bottom row: chips + action
                  Row(children: [
                    _Chip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Need ${product.minItems}',
                      color: canCraft
                          ? cat.color
                          : shortage > 0
                              ? Colors.orange
                              : Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      icon: Icons.bolt_rounded,
                      label: '+${product.xp} XP',
                      color: Colors.amber,
                    ),
                    const Spacer(),
                    if (isCrafted)
                      Icon(Icons.check_circle_rounded,
                          color: cat.color, size: 22)
                    else if (canCraft)
                      _CraftBtn(color: cat.color, onTap: onCraft)
                    else if (shortage > 0)
                      _Chip(
                        icon: Icons.warning_amber_rounded,
                        label: 'Need $shortage more',
                        color: Colors.orange,
                        faint: true,
                      ),
                  ]),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  EDUCATIONAL CALLOUT — category-level fact strip
// ════════════════════════════════════════════════════════════════════════════
class _EduCallout extends StatelessWidget {
  final _WasteCategory cat;
  const _EduCallout({required this.cat});

  static const Map<String, String> _facts = {
    'plastic':
        '🌍  Globally only 9 % of all plastic ever produced has been recycled. '
        'Community action is one of the most impactful ways to change this.',
    'organic':
        '🌱  Up to 50 % of household solid waste is organic. Composting it '
        'instead of landfilling cuts greenhouse gases equivalent to removing '
        'millions of cars from the road.',
    'glass':
        '♾️   Glass is 100 % recyclable, infinitely, with no quality loss. '
        'Yet 80 % of glass still ends up in landfill — a massive missed opportunity.',
    'metallic':
        '⚡  Aluminium recycling saves 95 % of the energy to mine new ore. '
        'Recycling all steel produced each year saves enough energy to power '
        '18 million homes annually.',
    'ewaste':
        '☣️   E-waste is the fastest-growing waste stream on Earth — 57 million '
        'tonnes per year — yet contains 60 % of the world\'s recoverable gold '
        'and significant rare-earth metals.',
  };

  @override
  Widget build(BuildContext context) {
    final fact = _facts[cat.key];
    if (fact == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cat.color.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📚', style: TextStyle(fontSize: 16, color: cat.color)),
        const SizedBox(width: 9),
        Expanded(child: Text(fact,
            style: const TextStyle(
                color: Color(0xFF4A7095),
                fontSize: 11, height: 1.5,
                fontStyle: FontStyle.italic))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FOOTER BAR
// ════════════════════════════════════════════════════════════════════════════
class _FooterBar extends StatelessWidget {
  final int totalItems, craftedCount, ecoPoints, ecoCreativity;
  final bool mobile;
  final VoidCallback onFinish;

  const _FooterBar({
    required this.totalItems, required this.craftedCount,
    required this.ecoPoints,  required this.ecoCreativity,
    required this.mobile,     required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: mobile ? 13 : 18, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1525),
        border: Border(top: BorderSide(color: Color(0xFF1C2E45))),
      ),
      child: Row(children: [
        Expanded(child: Wrap(spacing: 14, runSpacing: 4, children: [
          _FStat('🗑️', '$totalItems', 'items'),
          _FStat('🔨', '$craftedCount', 'crafted'),
          _FStat('⭐', '$ecoPoints', 'eco pts'),
        ])),
        GestureDetector(
          onTap: onFinish,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF43A047).withValues(alpha: 0.3),
                  blurRadius: 9, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('✅', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text('Finish',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: mobile ? 12 : 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _FStat extends StatelessWidget {
  final String e, v, l;
  const _FStat(this.e, this.v, this.l);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(e, style: const TextStyle(fontSize: 13)),
    const SizedBox(width: 4),
    Text(v, style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    const SizedBox(width: 3),
    Text(l, style: const TextStyle(color: Color(0xFF3A5A78), fontSize: 11)),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
//  FINISH DIALOG
// ════════════════════════════════════════════════════════════════════════════
class _FinishDialog extends StatelessWidget {
  final int crafted, ecoCreativity, ecoPoints;
  final VoidCallback onClose;

  const _FinishDialog({
    required this.crafted, required this.ecoCreativity,
    required this.ecoPoints, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0C1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: const Color(0xFF43A047).withValues(alpha: 0.45), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 50)),
          const SizedBox(height: 10),
          const Text('Workshop Complete!',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 5),
          const Text('Great work turning sorted waste into\nuseful products.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4A7095),
                  fontSize: 13, height: 1.4)),
          const SizedBox(height: 20),
          _DStat('🔨', 'Items Crafted',     crafted),
          const SizedBox(height: 8),
          _DStat('⚡', 'Eco-Creativity XP', ecoCreativity),
          const SizedBox(height: 8),
          _DStat('⭐', 'Eco-Points',        ecoPoints),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.check_rounded),
            label: const Text('FINISH SESSION',
                style: TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
      ),
    );
  }
}

class _DStat extends StatelessWidget {
  final String e, l; final int v;
  const _DStat(this.e, this.l, this.v);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(e, style: const TextStyle(fontSize: 17)),
    const SizedBox(width: 10),
    Expanded(child: Text(l, style: const TextStyle(
        color: Color(0xFF4A7095), fontSize: 14))),
    Text('$v', style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
//  SMALL REUSABLE WIDGETS
// ════════════════════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  final IconData? icon;
  final bool   faint;

  const _Chip({
    required this.label, required this.color,
    this.icon, this.faint = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: faint ? 0.08 : 0.10),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
      ],
      Text(label, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _CraftBtn extends StatelessWidget {
  final Color color; final VoidCallback onTap;
  const _CraftBtn({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.65),
        ]),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 7, offset: const Offset(0, 2))],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text('🔨', style: TextStyle(fontSize: 12)),
        SizedBox(width: 5),
        Text('CRAFT', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold,
            fontSize: 10, letterSpacing: 0.7)),
      ]),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  final int count; final Color color; final bool empty;
  const _CountBadge({required this.count, required this.color, required this.empty});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: empty
          ? Colors.white.withValues(alpha: 0.05)
          : color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
          color: empty ? Colors.white12 : color.withValues(alpha: 0.35)),
    ),
    child: Text(
      empty ? 'Empty' : '$count items',
      style: TextStyle(
          color: empty ? const Color(0xFF2A4A66) : color,
          fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final double size; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, color: Colors.white60, size: size),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════════════
class _WasteCategory {
  final String key, label, emoji, binNote;
  final Color  color, shade;
  final int    count;
  final List<_Product> products;

  const _WasteCategory({
    required this.key,    required this.label,   required this.emoji,
    required this.binNote, required this.color,  required this.shade,
    required this.count,  required this.products,
  });
}

class _Product {
  final String emoji, name, desc, fact;
  final int    minItems, xp;

  const _Product(this.emoji, this.name, this.desc,
      this.minItems, this.xp, this.fact);
}