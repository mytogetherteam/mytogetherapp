import 'dart:io';

void main() {
  final file = File('lib/features/visa/presentation/screens/visa_page.dart');
  var lines = file.readAsLinesSync();
  
  final startIdx = lines.indexWhere((l) => l.startsWith('final List<_ServiceCategory> _serviceCategories = ['));
  final endIdx = lines.indexWhere((l) => l.startsWith('// ---------------------------------------------------------------------------'), startIdx) - 1;

  final newContent = r'''
final List<_ServiceCategory> _serviceCategories = [
  _ServiceCategory(
    label: 'Mandatory Reporting',
    emoji: '📋',
    color: const Color(0xFF3B82F6),
    items: [
      _ServiceItem(
        title: '90-Day Reporting (TM.47)',
        subtitle: 'Address reporting every 90 days',
        description: 'Long-term visa holders must report their residential address to the Immigration Bureau every 90 days of continuous stay in Thailand. Getting this done late incurs a 2,000 THB fine. You can complete this report in person, by mail, or through the official Thai Immigration e-Service portal online.',
        icon: PhosphorIconsRegular.calendarCheck,
        imageUrl: 'https://images.unsplash.com/photo-1543269865-cbf427effbad?q=80&w=800&auto=format&fit=crop',
        officialWebsite: 'https://tm47.immigration.go.th/tm47/#/login',
        canTakeAppointmentOnline: true,
      ),
      _ServiceItem(
        title: 'TM.30 (Residence Notification)',
        subtitle: 'Filed by landlord within 24 hours',
        description: 'Under the Immigration Act, the property owner or landlord must report the presence of any foreigner staying at their residence within 24 hours of arrival. While the landlord usually files the TM.30 online, the foreigner must keep the TM.30 receipt in their passport for subsequent visa extensions and 90-day reporting.',
        icon: PhosphorIconsRegular.house,
        imageUrl: 'https://images.unsplash.com/photo-1558036117-15d82a90b9b1?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'TDAC (Digital Arrival Card)',
        subtitle: 'Digital alternative to TM.6 card',
        description: 'The traditional TM.6 Arrival Card is being replaced by the Thailand Digital Arrival Card (TDAC) and ETA system. While currently suspended for air arrivals from most countries to ease airport congestion, the digital integration allows immigration pre-screening. Ensure you check current requirements before traveling if entering by land.',
        icon: PhosphorIconsRegular.deviceMobile,
        imageUrl: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?q=80&w=800&auto=format&fit=crop',
      ),
    ],
  ),
  _ServiceCategory(
    label: 'Visa Maintenance & Extensions',
    emoji: '🔄',
    color: const Color(0xFF8B5CF6),
    items: [
      _ServiceItem(
        title: 'Extension of Stay (TM.7)',
        subtitle: 'Extend your visa at Immigration',
        description: 'An extension of stay (using form TM.7) is applied for at a Thai Immigration Office. A 60-day tourist visa or visa exemption can typically be extended for an additional 30 days for a fee of 1,900 THB. Long-term visas (business, education, retirement) require extensive annual renewal paperwork submitted via TM.7.',
        icon: PhosphorIconsRegular.clockCounterClockwise,
        imageUrl: 'https://images.unsplash.com/photo-1544256718-3bcf237f3974?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Re-Entry Permit (TM.8)',
        subtitle: 'Required before leaving Thailand',
        description: 'If you leave Thailand, your current visa is automatically canceled unless you have a Re-Entry Permit. Form TM.8 allows you to obtain a Single-Entry (1,000 THB) or Multiple-Entry (3,800 THB) permit. This keeps your current visa valid while you travel abroad. Apply at Immigration or at major airports before departure.',
        icon: PhosphorIconsRegular.arrowUUpLeft,
        imageUrl: 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Visa Type Change (TM.86/87)',
        subtitle: 'Change visa type without leaving',
        description: 'Forms TM.86 and TM.87 allow foreigners to change their visa status (e.g., from a Tourist Visa or Exemption to a Non-Immigrant Visa) without leaving Thailand. This requires at least 15 days remaining on the current stamp, and significant supporting documentation from a sponsor, employer, or family member.',
        icon: PhosphorIconsRegular.swap,
        imageUrl: 'https://images.unsplash.com/photo-1450101499163-c8848c66cb85?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Transfer Stamp',
        subtitle: 'Move visas to a new passport',
        description: 'When you receive a new passport from your embassy while staying in Thailand, your existing Thai visa and entry stamps must be transferred from the old passport to the new one. This free service is done at the Immigration Office that issued your most recent visa extension or at the airport.',
        icon: PhosphorIconsRegular.stamp,
        imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=800&auto=format&fit=crop',
      ),
    ],
  ),
  _ServiceCategory(
    label: 'Work & Legal Documents',
    emoji: '💼',
    color: const Color(0xFF059669),
    items: [
      _ServiceItem(
        title: 'Digital Work Permit (e-WP)',
        subtitle: 'Legal authorization to work',
        description: 'Foreigners legally employed in Thailand must hold a Work Permit. The physical blue books have been heavily replaced by the Digital Work Permit (e-WP) application on smartphones. The employer must coordinate with the Ministry of Labour to secure the Work Permit before you can legally begin working.',
        icon: PhosphorIconsRegular.briefcase,
        imageUrl: 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Certificate of Residence',
        subtitle: 'Official proof of Thai address',
        description: 'A Certificate of Residence is an official document from Immigration or your Embassy confirming your Thai address. It is frequently required for buying a vehicle, applying for a Thai driver\'s license, opening a bank account, or acquiring utilities. You must show proof of address like a lease contract and a TM.30 receipt.',
        icon: PhosphorIconsRegular.certificate,
        imageUrl: 'https://images.unsplash.com/photo-1603796846054-e2ef6cc2878d?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Income Certificate',
        subtitle: 'Embassy letter verifying income',
        description: 'An Income Certificate is an official letter from a foreign embassy verifying a foreigner\'s pension or steady monthly income from abroad. This is commonly required for Retirement Visa applications (e.g., proving monthly income of at least 65,000 THB) or Marriage Visas (40,000 THB).',
        icon: PhosphorIconsRegular.money,
        imageUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Permanent Residency (PR)',
        subtitle: 'Indefinite stay for qualified residents',
        description: 'Permanent Residency allows you to stay in Thailand indefinitely without applying for annual extensions. Criteria are highly strict: you must hold a Non-Immigrant visa for at least 3 consecutive years, speak conversational Thai, and show significant tax payments. An annual quota of 100 people per nationality is enforced.',
        icon: PhosphorIconsRegular.mapPin,
        imageUrl: 'https://images.unsplash.com/photo-1473186578172-c141e6798fec?q=80&w=800&auto=format&fit=crop',
      ),
    ],
  ),
  _ServiceCategory(
    label: 'Health & Identification',
    emoji: '🏥',
    color: const Color(0xFFEC4899),
    items: [
      _ServiceItem(
        title: 'Medical Certificate for Visa',
        subtitle: 'Health check for Work Permits',
        description: 'A standardized medical certificate is required for Work Permits and certain long-term visas. A doctor at a certified Thai clinic or hospital must examine you (including a blood test) and verify that you do not suffer from prohibitive diseases like late-stage syphilis, tuberculosis, drug addiction, alcoholism, or elephantiasis.',
        icon: PhosphorIconsRegular.heartbeat,
        imageUrl: 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'ThaiID App Verification',
        subtitle: 'Digital identity application',
        description: 'ThaID is a digital identity application developed by the Department of Provincial Administration (DOPA). While primarily for Thai citizens, expats with specific residency status and pink cards can use it to securely verify their identity when accessing government e-services, filing taxes remotely, and verifying banking transactions.',
        icon: PhosphorIconsRegular.fingerprint,
        imageUrl: 'https://images.unsplash.com/photo-1585076641399-5c06d15a43ce?q=80&w=800&auto=format&fit=crop',
      ),
    ],
  )
];
''';

  lines.replaceRange(startIdx, endIdx, [newContent]);
  file.writeAsStringSync(lines.join('\n'));
  print('Fixed _serviceCategories successfully');
}
