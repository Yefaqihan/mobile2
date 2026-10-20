import 'package:flutter/material.dart';

const resqOrange = Color(0xFFFF5722);
const resqBlue = Color(0xFF1A237E);
const resqBg = Color(0xFFF5F7FA);
const resqRed = Color(0xFFD32F2F);

class ResQCard extends StatelessWidget {
  const ResQCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white});
  final Widget child; final EdgeInsets padding; final Color color;
  @override Widget build(BuildContext context) => Container(
    width: double.infinity, padding: padding,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 18, offset: const Offset(0, 7))]),
    child: child);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title; final String? subtitle;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: resqBlue)),
    if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: TextStyle(color: Colors.blueGrey.shade600, height: 1.35))],
  ]);
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label; final VoidCallback? onPressed; final IconData? icon;
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
    onPressed: onPressed, icon: Icon(icon ?? Icons.arrow_forward_rounded), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    style: ElevatedButton.styleFrom(backgroundColor: resqOrange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))));
}
