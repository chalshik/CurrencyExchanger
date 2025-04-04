import sys
import os

# Add the path to your application directory
path = '/home/chigurick/currencyexchangeserver/backend'
if path not in sys.path:
    sys.path.append(path)

# Import your Flask application
from server import app as application

# This object is used by the WSGI server to serve your app
# Make sure it matches what PythonAnywhere expects in the WSGI configuration 