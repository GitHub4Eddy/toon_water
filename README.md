# toon_water
This Quickapp retrieves water consumption from the Toon Watermeter
The main devices containes the Water Flow (liters/minute)
This QuickApp has Child Device for Water Total (m³)

See http://www.toonwater.nl for the device and more info

Version 0.2 (20th February 2022)
- Better check for bad responses Toon Water

Version 0.1 (1st Januari 2022)
- Initial version


Variables (mandatory): 
- IPaddress = IP address of your Toonwater meter
- Interval = Number in seconds 
- debugLevel = Number (1=some, 2=few, 3=all, 4=simulation mode) (default = 1)
