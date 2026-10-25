/// All contacts are fictional, non-actionable demonstration data.
class DemoDoctor {
  const DemoDoctor(
    this.name,
    this.specialty,
    this.clinic,
    this.city,
    this.email,
  );
  final String name, specialty, clinic, city, email;
  String get phone => '+91 XXXXX XXXXX';
}

abstract final class DemoDoctorDirectory {
  static const notice =
      'Demo directory — fictional doctors and contact details.';
  static const doctors = [
    DemoDoctor(
      'Dr. Aster Demo',
      'Gynecology',
      'Example Petal Clinic',
      'Pune',
      'aster.demo@example.com',
    ),
    DemoDoctor(
      'Dr. Iris Demo',
      'Gynecology',
      'Example Cloud Clinic',
      'Delhi',
      'iris.demo@example.com',
    ),
    DemoDoctor(
      'Dr. Rowan Demo',
      'Endocrinology',
      'Example Rhythm Clinic',
      'Bengaluru',
      'rowan.demo@example.com',
    ),
    DemoDoctor(
      'Dr. Sage Demo',
      'Endocrinology',
      'Example Bloom Clinic',
      'Chennai',
      'sage.demo@example.com',
    ),
    DemoDoctor(
      'Dr. Clover Demo',
      'General practice',
      'Example Haven Clinic',
      'Mumbai',
      'clover.demo@example.com',
    ),
    DemoDoctor(
      'Dr. Hazel Demo',
      'General practice',
      'Example Meadow Clinic',
      'Hyderabad',
      'hazel.demo@example.com',
    ),
  ];
  static List<DemoDoctor> search({
    String name = '',
    String specialty = 'All',
  }) => doctors
      .where(
        (d) =>
            (specialty == 'All' || d.specialty == specialty) &&
            d.name.toLowerCase().contains(name.trim().toLowerCase()),
      )
      .toList();
}
