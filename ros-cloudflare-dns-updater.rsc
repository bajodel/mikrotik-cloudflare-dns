##  <<  For parameters'details see README.md @ https://github.com/bajodel/mikrotik-cloudflare-dns  >>

## ---- Configuration/Start  -----

# Define here single/multiple Dns Records (FQDNs) with their Zone IDs, Record IDs, and AuthTokens
# (hint: populate at least the first (single record to update), uncomment the second one or create more as needed)
:local ParamVect {
                  "_____mywanip1_domain_com_____"={
      "DnsZoneID"="__Cloudflare_Dns_Zone_ID1____";
      "DnsRcrdID"="__Cloudflare_Dns_Record_ID1__";
      "AuthToken"="_Cloudflare_Auth_Key_Token_1_";
  };
#                 "_____mywanip2_domain_com_____"={
#     "DnsZoneID"="__Cloudflare_Dns_Zone_ID2____";
#     "DnsRcrdID"="__Cloudflare_Dns_Record_ID2__";
#     "AuthToken"="_Cloudflare_Auth_Key_Token_2_";
# };
}

# [default: false] enable verbose (debug) log messages, by default only changes will be logged
:local VerboseLog false
  
# [default: false] enable TestMode -> it will only monitor/log Wan IPv4 changes (no Cloudflare DNS update)
:local TestMode false

# [default: false] enable certificate validation for Cloudflare API calls (but before install RootCA used by CF)
:local CertCheck false

## ---- Configuration/End  ----

:global CFWanIP4Cur
:do {
:local ChkIpResult [:tool fetch url="http://checkip.amazonaws.com/" as-value output=user]
:if ($ChkIpResult->"status" = "finished") do={
  :local CFWanIP4New [:pick ($ChkIpResult->"data") 0 ( [ :len ($ChkIpResult->"data") ] -1 )]
  :if ($CFWanIP4New != $CFWanIP4Cur) do={
    # validate the new retrieved Wan IPv4
    :local CFWanIPv4IsValid true
    :local CFWanIP4NewMasked ($CFWanIP4New&255.255.255.255)
    :if ( :toip $CFWanIP4New != :toip $CFWanIP4NewMasked ) do={ :set CFWanIPv4IsValid true } else={ :set CFWanIPv4IsValid false }
    # if retrieved Wan IPv4 is valid proceed, skip update and log error if not valid
    :if ($CFWanIPv4IsValid) do={
      :if ($VerboseLog = true) do={ :log info "[CFUpdate script] New Wan IPv4 is valid ($CFWanIP4New)" }
      # Wan IP changed (valid and different from previously stored one)
      :log warning "[CFUpdate script] Wan IPv4 changed -> New IPv4: $CFWanIP4New - Old IPv4: $CFWanIP4Cur"
      # If not in "Test Mode" proceed with Cloudflare DNS update
      :if ($TestMode = false) do={
        # Loop through each DNS Record Names provided
        :foreach fqdn,params in=$ParamVect do={
          :local DnsRcName $fqdn
          :local DnsZoneID ($params->"DnsZoneID")
          :local DnsRcrdID ($params->"DnsRcrdID")
          :local AuthToken ($params->"AuthToken")
          :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Preparing CF-DNS-Update for <$DnsRcName>" }
          # create API update url for DNS Zone/Record
          :local url "https://api.cloudflare.com/client/v4/zones/$DnsZoneID/dns_records/$DnsRcrdID/"
          :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Generated URL for DNS update: $url" }
          :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Certificate check is globally set to $CertCheck" }
          # evaluating "check-certificate" (yes/no)
          :local CheckYesNo
          :if ($CertCheck = true) do={ :set CheckYesNo "yes" } else={ :set CheckYesNo "no" }
          # construct meaningful Comment, get Date/Time/SystemIdentity (removing blanks)
          :local ds [/system clock get date]
          :local ts [/system clock get time]
          :local datetime
          :set datetime ([:pick $ds 0 4] . "." . [:pick $ds 5 7] . "." . [:pick $ds 8 10] . "-" . [:pick $ts 0 2]. ":" .[:pick $ts 3 5])
          :local sysid value=[:tostr [/system identity get name]];
          :local safesysid; 
          :for i from=0 to=([:len $sysid]-1) do={ :local tmp [:pick $sysid $i];
          :if ($tmp !=" ") do={ :set safesysid "$safesysid$tmp" } }
          :local CFComment ("$datetime by $safesysid")
          :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Constructed Comment: $CFComment" }
          # updating the Cloudflare DNS Record
          :local CfApiResult [/tool fetch http-method=put mode=https url=$url check-certificate=$CheckYesNo output=user as-value \
          http-header-field="Authorization: Bearer $AuthToken,Content-Type: application/json" \
          http-data="{\"type\":\"A\",\"name\":\"$DnsRcName\",\"content\":\"$CFWanIP4New\",\"ttl\":60,\"proxied\":false,\"comment\":\"$CFComment\"}"]
          if ($CfApiResult->"status" = "finished") do={
            # log success message (:log warning used just to make it stand out in logs)
            :log warning "[CFUpdate script] Updated Cloudflare DNS record for <$DnsRcName> to $CFWanIP4New"
          } else={ :log error "[CFUpdate script] Error occurred updating Cloudflare DNS record for <$DnsRcName> to $CFWanIP4New" }
          # pause a little bit before the next one
          :delay 1
        }
      }
      # update stored global variable
      :set CFWanIP4Cur $CFWanIP4New
    } else={ :log error "[CFUpdate script] Error occurred, retrieved Wan IPv4 is invalid ($CFWanIP4New)" }
  } else={ :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Wan IPv4 didn't change ($CFWanIP4New)" } }
} else={ :log error "[CFUpdate script] Error occurred retrieving current Wan IPv4 (status: $ChkIpResult)" }
} on-error={ :log error "[CFUpdate script] Error occurred during Cloudflare DNS update process" }
