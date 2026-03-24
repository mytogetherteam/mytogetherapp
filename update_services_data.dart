import 'dart:io';

void main() {
  final file = File('lib/features/visa/presentation/screens/visa_page.dart');
  var content = file.readAsStringSync();

  // 1. Update _ServiceItem class
  content = content.replaceFirst(
'''class _ServiceItem {
  final String title;
  final String description;
  final IconData icon;''', 
'''class _ServiceItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;''');

  content = content.replaceFirst(
'''  const _ServiceItem({
    required this.title,
    required this.description,
    required this.icon,''', 
'''  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,''');

  // 2. Update _ServiceItemTile subtitle text
  content = content.replaceFirst(
'''      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          item.description,
          style: GoogleFonts.poppins(''', 
'''      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          item.subtitle,
          style: GoogleFonts.poppins(''');

  // 3. Update the _serviceCategories data objects
  final replacements = {
    "'90-Day Reporting (TM.47)'": "'Address reporting every 90 days'",
    "'TM.30 (Residence Notification)'": "'Filed by landlord within 24 hours'",
    "'TDAC (Digital Arrival Card)'": "'Digital alternative to TM.6 card'",
    "'Extension of Stay (TM.7)'": "'Extend your visa at Immigration'",
    "'Re-Entry Permit (TM.8)'": "'Required before leaving Thailand'",
    "'Visa Type Change (TM.86/87)'": "'Change visa type without leaving'",
    "'Transfer Stamp'": "'Move visas to a new passport'",
    "'Digital Work Permit (e-WP)'": "'Legal authorization to work'",
    "'Certificate of Residence'": "'Official proof of Thai address'",
    "'Income Certificate'": "'Embassy letter verifying income'",
    "'Permanent Residency (PR)'": "'Indefinite stay for qualified residents'",
    "'Medical Certificate for Visa'": "'Health check for Work Permits'",
    "'ThaiID App Verification'": "'Digital identity application'",
  };

  for (final entry in replacements.entries) {
    final titleMatch = "title: ${entry.key},";
    final subtitleInsert = "        subtitle: ${entry.value},";
    content = content.replaceFirst(titleMatch, "\$titleMatch\n\$subtitleInsert");
  }

  file.writeAsStringSync(content);
  print('Updated successfully');
}
