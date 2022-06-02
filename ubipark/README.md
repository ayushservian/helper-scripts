# ubipark.ps1

This powershell script can be used to book or cancel a parking spot for a given `$Date`

## Initialisation steps
The below steps are required to be run only once

### Step 1: Create ubiparkCreds.json file
Run the `. .\ubipark.ps1` script to run Init function that gets the values and creates the file

Alternatively you can directly create the `ubiparkCreds.json` file as a copy of the `ubiparkCreds.json.Sample` file

### Step 2: Book or Cancel

`. .\ubipark.ps1 Book`

`. .\ubipark.ps1 Cancel`

