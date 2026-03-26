import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// IMPORTANT: Ensure this import points to your actual painter file
import 'functions/heartBeatPainter.dart';

void main() {
  runApp(const MaterialApp(
    home: MedicalDashboard(),
    debugShowCheckedModeBanner: false,
  ));
}

class MedicalDashboard extends StatefulWidget {
  const MedicalDashboard({super.key});

  @override
  State<MedicalDashboard> createState() => _MedicalDashboardState();
}

class _MedicalDashboardState extends State<MedicalDashboard> {
  bool isDarkMode = true; // Global Theme State

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF020617) : const Color(0xFFE1E8EE);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // Sidebar Section
          SizedBox(
            width: 260,
            child: PatientSidebar(isDark: isDarkMode),
          ),
          // Main Content Section
          Expanded(
            child: Column(
              children: [
                // Header with dynamic metrics and theme toggle
                VitalMetricsHeader(
                  isDark: isDarkMode,
                  onThemeToggle: () => setState(() => isDarkMode = !isDarkMode),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkMode ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    child: WaveformSection(isDark: isDarkMode),
                  ),
                ),
                BottomStatusBar(isDark: isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Waveform Section (The Tiled Grid) ---
class WaveformSection extends StatefulWidget {
  final bool isDark;
  const WaveformSection({super.key, required this.isDark});

  @override
  State<WaveformSection> createState() => _WaveformSectionState();
}

class _WaveformSectionState extends State<WaveformSection> {
  bool _isFrozen = true; // Controls the "Pause" state globally for all waves

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildWaveformTile("Lead II", Colors.green, widget.isDark)),
        Expanded(child: _buildWaveformTile("Lead V1", Colors.green, widget.isDark)),
        Expanded(child: _buildWaveformTile("Lead V5", Colors.green, widget.isDark)),
        Expanded(child: _buildWaveformTile("Respiration (CO2)", Colors.blue, widget.isDark)),
        const Divider(height: 0.2),
        _buildBottomToolbar(),
      ],
    );
  }

  Widget _buildWaveformTile(String label, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              Text("1.0 mV",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF020617) : const Color(0xFFFBFDFF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: ClipRect(
                child: Stack(
                  children: [
                    CustomPaint(painter: MedicalGridPainter(isDark), size: Size.infinite),
                    // Now passing the _isFrozen state to the controller
                    AnimatedECG(
                      color: color,
                      isDark: isDark,
                      isFrozen: _isFrozen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
          const Text(" Zoom  ", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 12),
          // Functional Freeze Toggle
          InkWell(
            onTap: () => setState(() => _isFrozen = !_isFrozen),
            child: Row(
              children: [
                Icon(
                    _isFrozen ? Icons.play_arrow : Icons.pause,
                    size: 18,
                    color: _isFrozen ? Colors.orange : Colors.grey
                ),
                Text(
                    _isFrozen ? " RESUME  " : " FREEZE  ",
                    style: TextStyle(
                        fontSize: 12,
                        color: _isFrozen ? Colors.orange : Colors.grey,
                        fontWeight: _isFrozen ? FontWeight.bold : FontWeight.normal
                    )
                ),
              ],
            ),
          ),
          const Icon(Icons.print, size: 18, color: Colors.grey),
          const Text(" Print Strip", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
// --- Animation Manager (Passes data to your Painter) ---

class AnimatedECG extends StatefulWidget {
  final Color color;
  final bool isDark;
  final bool isFrozen; // This must be passed from WaveformSection

  const AnimatedECG({
    super.key,
    required this.color,
    required this.isDark,
    required this.isFrozen,
  });

  @override
  State<AnimatedECG> createState() => _AnimatedECGState();
}

class _AnimatedECGState extends State<AnimatedECG> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> currentBeatHeights = [];

  @override
  void initState() {
    super.initState();
    _generateNewSweepData();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Only get new peaks if we aren't frozen
        if (!widget.isFrozen) {
          _generateNewSweepData();
          _controller.forward(from: 0.0);
        }
      }
    });

    // Start animation if not frozen initially
    if (!widget.isFrozen) {
      _controller.forward();
    }
  }

  // THIS IS THE CRITICAL MISSING PIECE
  @override
  void didUpdateWidget(covariant AnimatedECG oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the frozen state changed
    if (widget.isFrozen != oldWidget.isFrozen) {
      if (widget.isFrozen) {
        _controller.stop(); // Freeze the scan head immediately
      } else {
        _controller.repeat(); // Resume moving
      }
    }
  }

  void _generateNewSweepData() {
    final rnd = math.Random();
    setState(() {
      // This creates a fresh set of heights for the NEXT 8 beats
      // Some will be tall (1.4), some will be short (0.5)
      currentBeatHeights = List.generate(8, (_) => 0.5 + rnd.nextDouble() * 0.9);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: HighEndECGPainter(
            sweepProgress: _controller.value,
            color: widget.color,
            isDarkMode: widget.isDark,
            beatHeights: currentBeatHeights,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

// --- Medical Grid ---

class MedicalGridPainter extends CustomPainter {
  final bool isDark;
  MedicalGridPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final Color gridColor = isDark ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.15);
    final Color majorGridColor = isDark ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.3);

    final lightPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    final darkPaint = Paint()..color = majorGridColor..strokeWidth = 1.0;

    for (double x = 0; x <= size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x / 10).round() % 5 == 0 ? darkPaint : lightPaint);
    }
    for (double y = 0; y <= size.height; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y / 10).round() % 5 == 0 ? darkPaint : lightPaint);
    }
  }

  @override
  bool shouldRepaint(MedicalGridPainter oldDelegate) => oldDelegate.isDark != isDark;
}

// --- Patient Info Sidebar ---

class PatientSidebar extends StatelessWidget {
  final bool isDark;
  const PatientSidebar({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final sidebarBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      color: sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF2C6BB0),
            width: double.infinity,
            child: const Text("Patient Profile",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          const Center(child: CircleAvatar(radius: 40, backgroundColor: Color(0xFFE1E8EE), child: Icon(Icons.person, size: 40))),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Sarah J. Chen\nID: SC-987654\nAge: 54 / F\nAdm: Mar 15, 2026",
                style: TextStyle(height: 1.6, fontSize: 13, color: textColor)),
          ),
          const Divider(),
          _sidebarItem("Overview", isSelected: true, isDark: isDark),
          _sidebarItem("History", isDark: isDark),
          _sidebarItem("Alarms", isDark: isDark),
        ],
      ),
    );
  }

  Widget _sidebarItem(String title, {bool isSelected = false, required bool isDark}) {
    return ListTile(
      dense: true,
      title: Text(title,
          style: TextStyle(color: isSelected ? Colors.blue : (isDark ? Colors.white60 : Colors.black54))),
      leading: isSelected ? Container(width: 4, height: 20, color: Colors.blue) : null,
    );
  }
}

// --- Metrics Header with Auto-Updates ---

class VitalMetricsHeader extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;
  const VitalMetricsHeader({super.key, required this.onThemeToggle, required this.isDark});

  @override
  State<VitalMetricsHeader> createState() => _VitalMetricsHeaderState();
}

class _VitalMetricsHeaderState extends State<VitalMetricsHeader> {
  late Timer _timer;
  final _random = math.Random();
  int hr = 78,
      rr = 18,
      spo2 = 98,
      qrs = 88,
  qt=375;
  double temp = 37.1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (t) {
      if (mounted) {
        setState(() {
          hr = 76 + _random.nextInt(5);
          rr = 17 + _random.nextInt(3);
          spo2 = 97 + _random.nextInt(3);
          temp = 37.0 + (_random.nextDouble() * 0.2);
          qrs = 85 + _random.nextInt(6);
          qt=375+_random.nextInt(16);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerBg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: headerBg,
      child: Row(
        children: [
          _buildMetricTile("HR", hr.toString(), "bpm", Colors.redAccent),
          _buildMetricTile("RR", rr.toString(), "bpm", Colors.blue),
          _buildMetricTile("SpO2", spo2.toString(), "%",
              widget.isDark ? Colors.cyan : Colors.black),
          _buildMetricTile("QRS", qrs.toString(), "ms",
              widget.isDark ? Colors.white : Colors.black),
          _buildMetricTile("QT", qt.toString(), "ms",
              widget.isDark ? Colors.white : Colors.black),
          _buildMetricTile(
              "TEMP", temp.toStringAsFixed(1), "°C", Colors.orange),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode,
                color: Colors.grey),
            onPressed: widget.onThemeToggle,
          )
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String val, String unit, Color color) {
    // Map labels to the specific icons from your image
    Widget getIcon(String l) {
      double iconSize = 22;
      switch (l) {
        case "HR":
          return Icon(Icons.favorite_rounded, color: Colors.redAccent,
              size: iconSize);
        case "RR":
          return Icon(Icons.heart_broken_outlined, color: Colors.blue.shade700,
              size: iconSize); // Requires Material Icons
        case "SpO2":
          return const Text("Normal",
              style: TextStyle(fontSize: 9,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Color(0xFFE8F5E9)));
        case "QRS":
          return Icon(
              Icons.show_chart, color: Colors.red.shade700, size: iconSize);
        case "QT":
          return Icon(
              Icons.straighten, color: Colors.blue.shade700, size: iconSize);
        case "TEMP":
          return Icon(
              Icons.thermostat, color: Colors.orange.shade800, size: iconSize);
        default:
          return Icon(Icons.analytics, color: color, size: iconSize);
      }
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // High contrast for Day mode, deep slate for Night mode
          color: widget.isDark ? const Color(0xFF1E293B) : (label == "HR"
              ? const Color(0xFFE8F5E9)
              : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            // Top Row: Label and Icon/Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white : Colors.black
                  ),
                ),
                getIcon(label),
              ],
            ),

            // Bottom Row: Value and Unit
            Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    val,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? color : Colors.black,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Status Bar ---

class BottomStatusBar extends StatelessWidget {
  final bool isDark;
  const BottomStatusBar({super.key, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final barBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textCol = isDark ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: barBg,
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.orange, size: 14),
          const SizedBox(width: 8),
          Text("SYSTEM STATUS: NOMINAL", style: TextStyle(fontSize: 11, color: textCol)),
          const Spacer(),
          Text("2026-03-27 | v3.1", style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}