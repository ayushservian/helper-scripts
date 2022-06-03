# ubipark.ps1

This powershell script can be used to book or cancel a parking spot for a given `$Date`

## Initialisation: Create ubiparkCreds.json file
Run the `. .\ubipark.ps1` script to run Init function that gets the values one by one and creates the file

Alternatively you can directly create the `ubiparkCreds.json` file as a copy of the `ubiparkCreds.json.Sample` file
To get the possible car park IDs run `. .\ubipark.ps1 IDs`

### Book or Cancel

`. .\ubipark.ps1` OR `. .\ubipark.ps1 Book` => To make a booking

`. .\ubipark.ps1 Cancel`

