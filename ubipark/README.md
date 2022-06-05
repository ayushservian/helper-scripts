# ubipark.ps1

This powershell script can be used to book or cancel a parking spot for a given date

## Initialisation: Create ubiparkCreds.json file
Run the `. .\ubipark.ps1 Init` script to run Init function that gets the values one by one and creates the file

Alternatively you can directly create the `ubiparkCreds.json` file as a copy of the `ubiparkCreds.json.Sample` file
To get the possible car park IDs, leave that value blank on the json file and then run `. .\ubipark.ps1 IDs` to get the ID and then update the json file

## Book or Cancel

`. .\ubipark.ps1` OR `. .\ubipark.ps1 Book` => To make a booking on a given date

`. .\ubipark.ps1 Cancel` => To cancel a booking for a given date

## Snippets

### Initialising
```
> . .\ubipark.ps1 Init
Lets create your config file (ubiparkCreds.json)
Please enter your email: tester@bunnings.com.au
Are you ok with storing password in plaintext on the config file ?
If you choose not to you'll need to enter password everytime you run the script (Y/n): Y
Please enter your password: ********
Please enter the <your-site> part of the base URI of your ubipark site (format: https://your-site.ubipark.com): testings
Please enter number plate of the vehicle to book the spot for: myplate
Getting Login Form
Getting session
initing
Getting Car Park List
1234 => Office 3
4567 => Office 9
Which car park would you like to book for?: 1234
Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: '', numberPlate: ''}
Please enter the date (in format yyyy-MM-dd) OR press enter if its for 2022-06-24: 2022-06-06
Getting Booking Form for 2022-06-06
Making a Booking Request
Getting booking details
Confirming the Booking
Parking reserved for 2022-06-06
```

### IDs
```
> . .\ubipark.ps1 IDs
initing
Getting Car Park List
1234 => Office 3
4567 => Office 9
```

### Booking Success
```
> . .\ubipark.ps1
Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: '', numberPlate: ''}
Please enter the date (in format yyyy-MM-dd) OR press enter if its for 2022-06-24: 2022-06-06
Getting Booking Form for 2022-06-06
Making a Booking Request
Getting booking details
Confirming the Booking
Parking reserved for 2022-06-06
```

### Booking Failed
```
> . .\ubipark.ps1 Book
Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: '', numberPlate: ''}
Please enter the date (in format yyyy-MM-dd) OR press enter if its for 2022-06-24: 2022-06-03
Getting Booking Form for 2022-06-03
Making a Booking Request
Getting booking details
Failed to book a spot for 2022-06-03
```

### Cancel Success
```
> . .\ubipark.ps1 Cancel
Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: '', numberPlate: ''}
Please enter the date (in format yyyy-MM-dd) OR press enter if its for 2022-06-03: 2022-06-23
Getting bookings for 2022-06-23
Requesting cancellation form <cancellation uri>
Cancelling Booking
Your Booking has been cancelled and a confirmation has been emailed
```
### Cancel Failed
```
> . .\ubipark.ps1 Cancel
Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: '', numberPlate: ''}
Please enter the date (in format yyyy-MM-dd) OR press enter if its for 2022-06-03:
Getting bookings for 2022-06-03
No bookings found!
```

## TODO
Change reserved bay if possible