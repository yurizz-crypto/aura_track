Aura Track 🌿
A Gamified Habit Tracker & Digital Sanctuary

Aura Track is a Flutter application that transforms daily habit building into a visual, interactive experience. Users "plant" habits, and completing them helps their digital garden bloom. The app utilizes device sensors for interactive verification of specific habits (walking, hydration, meditation).

📱 Features
Core Functionality
Digital Garden: Your home screen is a dynamic garden. The more points you earn, the more flowers bloom.

Gamification: Earn points and maintain streaks to unlock visual rewards (glowing flowers).

Calendar View: Track your history and see past "blooms" using a calendar interface.

Leaderboard: Compete with other users in the community based on points earned from interactive habits.

Authentication: Secure Email/Password login and signup via Supabase.

Role-Based Access: distinct dashboards for regular Users and Admins.

Interactive Sensor Games
Aura Track goes beyond checkboxes by using device hardware to verify habits:

Walking Habit: Uses the Pedometer sensor. Users must walk 20 meters/27 steps to complete the goal.

Hydration (Pour Water): Uses the Gyroscope. Users physically tilt their phone to "pour" water into a virtual glass.

Meditation: Uses the Accelerometer. Users must keep their phone perfectly still for 15 seconds to achieve "Zen".

🛠 Tech Stack
Frontend: Flutter (Dart)

Backend: Supabase (PostgreSQL, Auth, Edge Functions)

State Management: StatefulWidget / setState (Local state management)

Key Dependencies:

supabase_flutter: Backend integration.

sensors_plus: Access to Accelerometer and Gyroscope.

pedometer: Step counting.

permission_handler: Managing Android/iOS permissions.

audioplayers: Sound effects.

table_calendar: History visualization.

google_fonts: Typography (Poppins).