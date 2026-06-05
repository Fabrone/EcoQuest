import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;

// ── Add/replace in soil_pollution_models.dart ────────────────────────────────

enum SoilLevelCompletionState { failed, moderate, fullRemediation }

class SoilPollutionResult {
  final int    zonesRemediated;
  final int    zonesPhysical;
  final int    correctTools;
  final int    wrongTools;
  final int    ecoPoints;
  final double soilHealth;
  final bool   soilGuardianBadge;
  final int    scannedZones;
  final int    maxCombo;
  final int    scanStreakBonus;
  final int    ecoDiscoveriesFound;
  final bool   timeBonusCollected;
  final int    criticalSaves;
  final int    zonesExpanded;
  final int    resupplyTriggered;
  final bool   meetsMinimum;
  final int    minimumRequired;
  final String                   endReason;
  final SoilLevelCompletionState completionState;

  const SoilPollutionResult({
    required this.zonesRemediated,
    required this.zonesPhysical,
    required this.correctTools,
    required this.wrongTools,
    required this.ecoPoints,
    required this.soilHealth,
    required this.soilGuardianBadge,
    required this.scannedZones,
    this.maxCombo            = 1,
    this.scanStreakBonus      = 0,
    this.ecoDiscoveriesFound  = 0,
    this.timeBonusCollected   = false,
    this.criticalSaves        = 0,
    this.zonesExpanded        = 0,
    this.resupplyTriggered    = 0,
    this.meetsMinimum         = false,
    this.minimumRequired      = 8,
    this.endReason            = 'Level completed.',
    this.completionState      = SoilLevelCompletionState.failed,
  });

  int get totalActions => correctTools + wrongTools;
  int get accuracyPct  => totalActions == 0
      ? 0 : ((correctTools / totalActions) * 100).round();

  String get performanceGrade {
    if (accuracyPct >= 85 && zonesRemediated >= 7) return 'EXPERT REMEDIATOR';
    if (accuracyPct >= 70 && zonesRemediated >= 5) return 'SKILLED SOIL SCIENTIST';
    if (accuracyPct >= 50 && zonesRemediated >= 3) return 'FIELD TRAINEE';
    return 'APPRENTICE ECOLOGIST';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (criticalSaves > 0)        lines.add('Saved $criticalSaves critical zone(s) before collapse');
    if (zonesExpanded > 0)        lines.add('$zonesExpanded contamination zone(s) expanded due to neglect');
    if (ecoDiscoveriesFound > 0)  lines.add('Found $ecoDiscoveriesFound hidden Eco-Discovery marker(s)');
    if (timeBonusCollected)       lines.add('Time Bonus zone restored - earned +8 s');
    if (maxCombo >= 4)            lines.add('$maxCombo-streak combo achieved - 3× point multiplier!');
    if (scanStreakBonus > 0)      lines.add('Scan streak bonus: +$scanStreakBonus pts');
    return lines.isEmpty ? 'Complete all zones to maximise your score.' : lines.join('\n');
  }

  static SoilPollutionResult? current;
}

// ── Enums ─────────────────────────────────────────────────────────────────────
enum SoilPollutantType {
  oilSpill,
  acidicSoil,
  heavyMetals,
  pesticides,
  compactSoil,
}

enum RemediationTool {
  // Physical — Step ①
  containmentBoom,
  pHAmendment,
  soilExcavation,
  soilWashing,
  aerationTill,
  // Biological — Step ②
  biocharBacteria,
  limeCompost,
  phytoPlants,
  compostWorms,
  mycorrhizae,
}

enum RemediationStep { none, physical, remediated }

enum ScanLayerType { topLayer, midLayer, deepLayer }

// ── Soil scan result (auto-detected after hover-lock in Phase 3) ──────────────
class SoilScanResult {
  final SoilPollutantType type;
  final String typeName, severity, ecoFact, step1Tool, step2Tool, icon;
  final Color  color;
  final bool   hasEcoDiscovery;
  final String discoveryFact;

  const SoilScanResult({
    required this.type,
    required this.typeName,
    required this.severity,
    required this.ecoFact,
    required this.step1Tool,
    required this.step2Tool,
    required this.icon,
    required this.color,
    this.hasEcoDiscovery = false,
    this.discoveryFact   = '',
  });

  // ── Factory: builds scan result with Kiambu-specific eco-facts ─────────────
  static SoilScanResult forType(
    SoilPollutantType t, {
    bool withDiscovery = false,
    int  variant       = 0,
  }) {
    const oilFacts = [
      'Hydrocarbon contamination from agrochemical spills in Kiambu penetrates 40 cm into topsoil within 72 hours — threatening root systems.',
      'A single 5-litre oil spill can contaminate 1,000 litres of groundwater below the Kiambu ridge, affecting downstream farming wells.',
    ];
    const acidFacts = [
      'Decades of ammonium fertiliser in Kiambu\'s tea estates lowered soil pH to 4.2 — toxic to most crop roots and soil microbes.',
      'Acid soil renders phosphorus unavailable to plants, increasing fertiliser dependency by 300% on Kiambu\'s smallholder farms.',
    ];
    const metalFacts = [
      'Runoff from Gikambura light industries has deposited 4× safe lead levels in subsoil below local subsistence farms.',
      'Lead and cadmium from vehicle exhaust accumulate in Kiambu\'s deep soil layer for over 100 years without active intervention.',
    ];
    const pesticideFacts = [
      'DDT applied in Kiambu\'s highlands in the 1970s is still detected in mid-layer soils — persisting over 50 years after application.',
      'Organophosphate pesticide runoff from Kiambu farms reduces soil microbial diversity by 80% within the mid-layer band.',
    ];
    const compactFacts = [
      'In Kiambu\'s highlands, 60% of topsoil has bulk density above 1.6 g/cm³ — too dense for maize roots to penetrate beyond 10 cm.',
      'Mechanised clearing of Kiambu\'s highland forests for colonial tea estates compacted subsoil to 60 cm depth — effects still persist today.',
    ];

    const discoveryFacts = {
      SoilPollutantType.oilSpill:
        '🏺 Soil Story: Gikambura\'s Kikuyu elders buried "githuri" (sealed clay pots of organic matter) in oil-contaminated ground — an ancestral biochar technique predating modern remediation by centuries.',
      SoilPollutantType.acidicSoil:
        '🌿 Cultural Marker: Kiambu farmers once intercropped "mukinduri" trees to naturally buffer soil acidity — a forgotten indigenous pH management practice still visible in old-growth plots.',
      SoilPollutantType.heavyMetals:
        '⚙️ Industrial Legacy: Colonial-era processing plants near Kiambu left heavy metal residues still detectable 80 years later — a hidden cost of the colonial tea economy buried in the deep layer.',
      SoilPollutantType.pesticides:
        '🧪 Historical Record: DDT stockpiles from 1960s locust control programmes were buried near Gikambura — the pesticide plumes still migrate through soil and are found in community borehole water.',
      SoilPollutantType.compactSoil:
        '🚜 Land History: Mechanised clearing of Kiambu\'s forests for colonial tea estates in the 1950s compacted subsoil to 60 cm depth — directly reducing modern farm yields by up to 40%.',
    };

    final idx = variant % 2;
    switch (t) {
      case SoilPollutantType.oilSpill:
        return SoilScanResult(
          type: t, typeName: 'Hydrocarbon Oil Spill',
          severity: 'HIGH  •  Topsoil penetration',
          ecoFact:  oilFacts[idx],
          step1Tool: 'Containment Boom  →  Physically contains and extracts oil from surface',
          step2Tool: 'Biochar + Bacteria  →  Microbial cultures break down residual hydrocarbons',
          icon: '🛢️', color: const Color(0xFF424242),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case SoilPollutantType.acidicSoil:
        return SoilScanResult(
          type: t, typeName: 'Severe Soil Acidification',
          severity: 'MEDIUM  •  pH < 4.5',
          ecoFact:  acidFacts[idx],
          step1Tool: 'pH Amendment (Lime)  →  Chemically neutralises soil acidity',
          step2Tool: 'Lime + Compost  →  Re-introduces microbial life and organic buffering',
          icon: '⚗️', color: const Color(0xFFCDDC39),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case SoilPollutantType.heavyMetals:
        return SoilScanResult(
          type: t, typeName: 'Heavy Metal Contamination',
          severity: 'SEVERE  •  Deep layer toxicity',
          ecoFact:  metalFacts[idx],
          step1Tool: 'Soil Excavation  →  Physically removes most-contaminated material',
          step2Tool: 'Phyto-Plants  →  Hyperaccumulator plants extract residual metals over time',
          icon: '⚙️', color: const Color(0xFF7B1FA2),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case SoilPollutantType.pesticides:
        return SoilScanResult(
          type: t, typeName: 'Pesticide Residue Zone',
          severity: 'MEDIUM  •  Persistent organics',
          ecoFact:  pesticideFacts[idx],
          step1Tool: 'Soil Washing  →  Flushes soluble pesticide residues from the soil matrix',
          step2Tool: 'Compost + Worms  →  Microbial worm activity metabolises remaining organics',
          icon: '🧪', color: const Color(0xFFFF6D00),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case SoilPollutantType.compactSoil:
        return SoilScanResult(
          type: t, typeName: 'Severely Compacted Soil',
          severity: 'LOW–MED  •  Hardpan layer',
          ecoFact:  compactFacts[idx],
          step1Tool: 'Aeration Tilling  →  Mechanically fractures hardpan and restores pore space',
          step2Tool: 'Mycorrhizae  →  Fungal networks rebuild soil structure and water channels',
          icon: '🪨', color: const Color(0xFFBCAAA4),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
    }
  }
}

// ── Leach zone — causes contamination spread; analogous to wind zone ──────────
class LeachZone {
  final Vector2 center;
  final double  radius;
  double        leachRate;

  LeachZone({
    required this.center,
    required this.radius,
    required this.leachRate,
  });
}