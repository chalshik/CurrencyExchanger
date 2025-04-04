# Currency Changer Application

A comprehensive currency exchange application built with Flutter for the frontend and Flask for the backend.

## Project Structure

- `/lib` - Flutter application code
- `/backend` - Flask server code
- `/assets` - Application assets including translations and images

## Quick Start

### Backend Server Setup

1. Navigate to the backend directory:
   ```
   cd backend
   ```

2. On Windows, you can run the batch file to set up and start the server:
   ```
   run_server.bat
   ```

   Alternatively, you can set up the server manually:
   ```
   # Create and activate virtual environment
   python -m venv venv
   venv\Scripts\activate  # On Windows
   source venv/bin/activate  # On macOS/Linux

   # Install dependencies
   pip install -r requirements.txt

   # Start the server
   python run.py
   ```

3. The server will start on `http://0.0.0.0:5000`

### Flutter Application Setup

1. Make sure you have Flutter installed. If not, follow the [official installation guide](https://flutter.dev/docs/get-started/install).

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Run the application:
   ```
   flutter run
   ```

   You can specify a device with:
   ```
   flutter run -d chrome  # For web
   flutter run -d android  # For Android
   flutter run -d ios      # For iOS
   ```

## Default Credentials

- Admin user: username: `a`, password: `a`

## Features

- Currency management (add, edit, delete currencies)
- Transaction history tracking
- User management with role-based access
- Analytics and statistics
- Multi-language support (English, Russian, Kyrgyz)
- Light and dark mode
- Data export (Excel, PDF)

## API Documentation

See the [backend README](backend/README.md) for detailed API documentation.
