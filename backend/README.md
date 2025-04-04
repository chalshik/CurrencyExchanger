# Currency Changer Backend Server

This is the backend server for the Currency Changer application, built with Flask and SQLAlchemy.

## Requirements

- Python 3.8 or higher
- pip (Python package installer)

## Installation

1. Create a virtual environment (recommended):

```bash
# On Windows
python -m venv venv
venv\Scripts\activate

# On macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

2. Install the required packages:

```bash
pip install -r requirements.txt
```

## Running the Server

To start the server, run:

```bash
python server.py
```

The server will start on `http://0.0.0.0:5000` and can be accessed from your Flutter application.

## API Endpoints

The server provides the following API endpoints:

### Authentication
- `POST /api/users/login` - User login

### Currencies
- `GET /api/currencies` - Get all currencies
- `GET /api/currencies/<code>` - Get currency by code
- `POST /api/currencies` - Create new currency
- `PUT /api/currencies/<id>` - Update currency
- `PUT /api/currencies/<code>/quantity` - Update currency quantity
- `DELETE /api/currencies/<id>` - Delete currency

### History
- `GET /api/history` - Get transaction history
- `GET /api/history/filter` - Filter history by date range
- `POST /api/history` - Create history entry
- `PUT /api/history/<id>` - Update history entry
- `DELETE /api/history/<id>` - Delete history entry

### Users
- `GET /api/users` - Get all users
- `POST /api/users` - Create new user
- `PUT /api/users/<id>` - Update user
- `DELETE /api/users/<id>` - Delete user
- `POST /api/users/check-username` - Check if username exists

### System
- `POST /api/system/reset` - Reset application data
- `GET /api/system/currency-summary` - Get currency summary
- `GET /api/system/history-codes` - Get distinct currency codes from history
- `GET /api/system/history-types` - Get distinct operation types from history
- `POST /api/system/exchange` - Perform currency exchange

### Connection Testing
- `GET /` - Heartbeat endpoint for connection checking

### Analytics
- `GET /api/analytics/daily-data` - Get daily data for bar charts
- `GET /api/analytics/pie-chart-data` - Get data for pie charts
- `GET /api/analytics/profitable-currencies` - Get most profitable currencies
- `GET /api/analytics/batch-data` - Get all analytics data in a single request

## Default Credentials

The server is initialized with the following default data:

- Admin user: username: `a`, password: `a`
- Default currency: `SOM` with quantity of 1000.0

## Database

The application uses SQLite for data storage. The database file `currency_changer.db` will be created in the backend directory when the server is first run. 