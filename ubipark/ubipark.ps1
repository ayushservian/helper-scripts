function Init {
    Write-Host "Lets create your config file (ubiparkCreds.json)"
    $email = Read-Host -Prompt "Please enter your email"

    $storePass = Read-Host "Are you ok with storing password in plaintext on the config file ?`nIf you choose not to you'll need to enter password everytime you run the script (Y/n)"
    if($storePass -eq "Y")
    {
        $SecurePassword = Read-Host -Prompt "Please enter your password" -AsSecureString
        $UnsecurePassword = (New-Object PSCredential "user",$SecurePassword).GetNetworkCredential().Password
    }

    $baseuri = Read-Host -Prompt "Please enter the <your-site> part of the base URI of your ubipark site (format: https://your-site.ubipark.com)"
    $baseuri = $baseuri.ToString().ToLower()

    $numPlate = Read-Host -Prompt "Please enter number plate of the vehicle to book the spot for"

    $Vals = @{
        "email" = $email
        "pass" = $UnsecurePassword
        "baseUri" = "https://${baseuri}.ubipark.com"
        "numberPlate" = $numPlate
    }

    $sess = GetUbiParkSession $Vals
    UbiParkList -altSession $sess -altBaseUri $Vals.baseUri
    $parkId = Read-Host -Prompt "Which car park would you like to book for?"

    $Vals.carParkID = $parkId
    Set-Content -Path .\ubiparkCreds.json -Value $($Vals | ConvertTo-Json)
}

function GetUbiParkVals {
    Write-Host "Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: '', numberPlate: ''}"
    $doesFileExist = Test-Path -Path .\ubiparkCreds.json -PathType Leaf
    if($doesFileExist){
        $creds = Get-Content -Raw -Path .\ubiparkCreds.json | ConvertFrom-Json
    }

    if($null -eq $creds){
        Write-Host "No creds json found!!"
        return $null;
    }

    return $creds
}

function GetUbiParkSession {
    param([Object]$Initing)
    $creds = $Vals

    if($null -ne $Initing){
        $creds = $Initing
        $BaseUri = $creds.baseUri
    }

    if($null -eq $creds){
        Write-Host "No creds found!!"
        return $null;
    }
    
    if(($null -eq $creds.pass) -or ($creds.pass.Length -eq 0) ){
        $SecurePassword = Read-Host -Prompt "Please enter your password" -AsSecureString
        $pass = (New-Object PSCredential "user",$SecurePassword).GetNetworkCredential().Password
    } else {
        $pass = $creds.pass
    }
    Write-Host "Getting Login Form"

    $urlencodedEmail = [System.Web.HttpUtility]::UrlEncode($creds.email)
    $urlencodedPass = [System.Web.HttpUtility]::UrlEncode($pass)

    $Uri = "${BaseUri}/Account/Login"

    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get -SessionVariable session
    $ReqVerification = GetReqVerToken($WebResp.Content)

    Write-Host "Getting session"
    $Body = "__RequestVerificationToken=${ReqVerification}&Email=${urlencodedEmail}&Password=${urlencodedPass}"
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Post `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    return $session
}

function GetUbiBookings {
    if($null -eq $session){
        Write-Host "No session!"
        return
    }
    Write-Host "Getting Car Park Bookings"
    $Uri = "${BaseUri}/UserPermit/Read?HistoricalItems=False"
    $Body = "sort=&page=1&pageSize=500&group=&filter="
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Post `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    $list = $WebResp.Content | ConvertFrom-Json
    $index = 0

    foreach ($park in $list.Data) {
        $booking = $park.EffectiveFrom.ToString().Split("T")[0]
        $response += @($booking)
        $index++
        Write-Host "$index. $booking ==> $($park.EffectiveFrom) => $($park.EffectiveTo)"
    }
    return $response
}

function UbiParkList {
    [CmdletBinding()]
    param([Microsoft.PowerShell.Commands.WebRequestSession]$altSession,[String]$altBaseUri)

    if($null -ne $altSession){
        Write-Host "initing"
        $session = $altSession
        $BaseUri = $altBaseUri
    }

    if($null -eq $session){
        Write-Host "No session!"
        return
    }
    Write-Host "Getting Car Park List"
    $Uri = "${BaseUri}/BookNow/GetCarParkList?rateGroupID=70"
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get `
                -WebSession $session
    $list = $WebResp.Content | ConvertFrom-Json
    foreach ($park in $list) {
        Write-Host "$($park.ID) => $($park.Name)"
    }
}

function UbiParkBook {
    # [CmdletBinding()]
    # param([Microsoft.PowerShell.Commands.WebRequestSession]$session, [String]$Date)

    if($null -eq $session){
        Write-Host "No session!"
        return
    }
    Write-Host "Getting Booking Form for $Date"
    $Uri = "${BaseUri}/BookNow"
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session
    $ReqVerification = GetReqVerToken($WebResp.Content)

    $Group = GetFormData $WebResp.Content "Group"

    Write-Host "Making a Booking Request"
    $Uri = "${BaseUri}/BookNow/Payment"
    $From = "${Date}T07%3A00%3A00.000"
    $To = "${Date}T19%3A15%3A00.000"
    $Body = "Group=${Group}&SelectedCarParkName=&RateGroupID=70&Hourly=True&ToDateDisplay=True&LicensePlateDisplay=True&FromDate=${From}&ToDate=${To}&PaymentGatewayID=1&PromoCodeID=&PromoCodeOneTimeUseID=&PromoCode=&DiscountPermitID=&CaptureNumberPlateRequired=True&NumberPlateRequiredRequired=True&MaxPurchaseDays=21&CustomTextDisplay=False&CustomTextRequired=False&CustomTextLabel=&CarParkID=${CarParkID}&FromDatePicker=27%2F05%2F2022&FromTimePicker=09%3A00&ToDatePicker=27%2F05%2F2022&ToTimePicker=09%3A15&LicensePlate_input=${NumberPlate}&LicensePlate=${NumberPlate}&CountryID=1&StateID=1&__RequestVerificationToken=${ReqVerification}&X-Requested-With=XMLHttpRequest"


    $PaymentResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method POST `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    $ReqVerification = GetReqVerToken($PaymentResp.Content)
    
    Write-Host "Getting booking details"
    $StationBayReservedID = GetFormData $PaymentResp.Content "StationBayReservedID"
    $StationBayID = GetFormData $PaymentResp.Content "StationBayID"
    $CardToken = GetFormData $PaymentResp.Content "CardToken"
    $UserID = GetFormData $PaymentResp.Content "UserID"
    $PermitID = GetFormData $PaymentResp.Content "PermitID"
    $PermitName = $(GetFormData $PaymentResp.Content "PermitName").Replace(" ","+")
    $CarParkName = $(GetFormData $PaymentResp.Content "CarParkName").Replace(" ","+")
    $BayLabel = "" #(GetFormData $WebResp.Content "BayLabel").Replace(" ","+")
    
    if($StationBayReservedID -eq "404"){
        return "Failed to book a spot for $Date"
    }    
    Write-Host "Confirming the Booking"
    $Uri = "${BaseUri}/BookNow/ProcessPayment"
    $Body = "Group=${Group}&UserPermitID=0&UserID=${UserID}&PermitID=${PermitID}&PermitName=${PermitName}&CarParkID=${CarParkID}&CarParkName=${CarParkName}&EffectiveFrom=${From}&EffectiveTo=${To}&Hourly=True&LicensePlate=${NumberPlate}&CountryID=1&StateID=1&StateCode=&PaymentAmount=0&PaymentGatewayID=1&CardToken=${CardToken}&HasCard=False&ReservedBays=True&ChangeBay=True&StationBayReservedID=${StationBayReservedID}&StationBayID=${StationBayID}&BayLabel=${BayLabel}&BayNotes=&TandemBayID=&PromoCodeID=&PromoCodeOneTimeUseID=&PromoCode=&DiscountPermitID=&Cost=0&Discount=0&CustomText=&__RequestVerificationToken=${ReqVerification}"

    # Write-Host $Body.Replace("&","`r`n")
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method POST `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    
    return "Parking reserved for $Date"
}

function UbiParkCancel {
    if($null -eq $session){
        Write-Host "No session!"
        return
    }
    Write-Host "Getting bookings for $Date"
    $Uri = "${BaseUri}/UserPermit/Read?HistoricalItems=False"
    $Body = "sort=&page=1&pageSize=500&group=&filter=EffectiveTo~lte~datetime'${Date}T23-00-00'~and~EffectiveFrom~gte~datetime'${Date}T00-00-00'"
    
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method POST `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body

    $Bookings = $WebResp.Content | ConvertFrom-Json
    $BookingID = $Bookings.Data[0].ID
    
    if($null -ne $BookingID){

        $Uri = "${BaseUri}/UserPermit/CancelPermit?id=${BookingID}"
        Write-Host "Requesting cancellation form $Uri"
        $WebResp = Invoke-WebRequest `
                    -Uri $Uri `
                    -Method Get `
                    -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                    -WebSession $session
    
        Write-Host "Cancelling Booking"
        $ReqVerification = GetReqVerToken($WebResp.Content)
        $Body = "__RequestVerificationToken=${ReqVerification}&UserPermitID=${BookingID}"
        $WebResp = Invoke-WebRequest `
                    -Uri $Uri `
                    -Method Post `
                    -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                    -WebSession $session `
                    -Body $Body 
        Write-Host "Your Booking has been cancelled and a confirmation has been emailed"
    } else {
        Write-Host "No bookings found!"
    }
}

function GetReqVerToken ([String]$WebResp) {
    return GetFormData $WebResp "__RequestVerificationToken"
}

function GetFormData  {
    [CmdletBinding()]
    param([String]$WebResp, [String]$Data)
    $DataValue = "404"
    if($WebResp.Contains("name=`"$Data`"")) {
        $Index1 = $WebResp.IndexOf("name=`"$Data`"")
        $ReqVerStart = $WebResp.Substring($Index1)
        $IndexVal = $ReqVerStart.IndexOf("value=")
        $IndexEnd = $ReqVerStart.IndexOf("/>")
        $DataValue = $ReqVerStart.Substring($IndexVal + 6, $IndexEnd - $IndexVal - 7).Replace("`"","")
    }
    # Write-Host $Data $DataValue
    return $DataValue
}

function CheckIntent {
    $doesFileExist = Test-Path -Path .\ubiparkCreds.json -PathType Leaf
    if($doesFileExist){
        do{
            $confirm = Read-Host "Do you want to overwrite existing config file from scratch (Y/n)?"
        } while (
            # ($null -ne $confirm) -and 
            (
                ($confirm -ne "Y") -and 
                ($confirm -ne "n"))
        )
        if($confirm -eq "n"){
            Write-Host "Taking you through booking.`r`nYou are also able to pass in an argument. Possible values are:`r`n1. IDs`r`n2. Book`r`n3. Cancel`r`n" 
            return $false
        }
    }
    return $true
}

function CheckDate {
    $date = $Date
    $isValidDate = $false
    [ref]$parsedDate = Get-Date

    if ([DateTime]::TryParseExact(
            $date, 
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            $parseddate)) {
        $isValidDate = $true
    } else {
        $isValidDate = $false
    }
    return $isValidDate
}

# if($null -eq $args[0]){
if($args[0] -eq 'Init'){
    $intent = CheckIntent
    if($intent){
        Init
    } 
    # else {
    #     return
    # }
}

$Vals = GetUbiParkVals
while($null -eq $Vals){
    Init
    $Vals = GetUbiParkVals
}

$BaseUri = $Vals.baseUri

$session = GetUbiParkSession
$bookedDates = GetUbiBookings
if($args[0] -ne "IDs"){
    # $Date = "2022-06-23"
    if($args[0] -eq "Cancel"){
        $DateIndex = Read-Host "Enter the index of the booking to be cancelled"
        $Date = $bookedDates[$DateIndex - 1]
        if($DateIndex -gt $bookedDates.Count) {
            Write-Host "Aborting cancellation"
            return
        }
    } else {
        $CarParkID = $Vals.carParkID
        $NumberPlate = $Vals.numberPlate
        $Assumption = $(Get-Date).AddDays(21).ToString("yyyy-MM-dd")

        do{
            $Date = Read-Host "Please enter the date (in format yyyy-MM-dd) OR press enter if its for $Assumption"
            if ($Date -eq ""){
                $Date = $Assumption
            }
            $isValidDate = CheckDate
        } while ($isValidDate -eq $false)
    }
}

switch ($args[0]) {
    "IDs" { UbiParkList }
    "Book" { UbiParkBook }
    "Cancel" { UbiParkCancel }
    Default { UbiParkBook }
}
