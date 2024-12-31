## ---- Configuration/Start  -----

# Cloudflare parameters (see README.md https://github.com/bajodel/mikrotik-cloudflare-dns )
# Cloudflare API token
:local CfApiAuthToken "__Cloudflare_Auth_Key_Token_";
# Define multiple subdomains with their Zone IDs and Record IDs
:local CfApiRecords {
    "mywanip1.domain.com"={
        "zoneID"="__Cloudflare_Dns_Zone_ID1____";
        "recordID"="__Cloudflare_Dns_Record_ID1__";
    };
    "mywanip2.domain.com"={
        "zoneID"="__Cloudflare_Dns_Zone_ID2____";
        "recordID"="__Cloudflare_Dns_Record_ID2__";
    };
}

# Enable or disable DNS updates
:local CfApiUpdEnable true;

# Certificate validation for API calls
:local CfApiCertCheck false;

## ---- Configuration/End  ----

:global WanIP4Cur

:log info "[script] Starting Cloudflare DNS update script"

:do {
    :log info "[script] Retrieving current WAN IP from http://checkip.amazonaws.com/"
    :local result [:tool fetch url="http://checkip.amazonaws.com/" as-value output=user]
    
    :if ($result->"status" = "finished") do={
        :local WanIP4New [:pick ($result->"data") 0 ( [ :len ($result->"data") ] -1 )]
        :log info "[script] Retrieved WAN IP: $WanIP4New and old recorded WAN IP is: $WanIP4Cur"
        
        :if ($WanIP4New != $WanIP4Cur) do={
            :log warning "[script] WAN IP has changed - New IP: $WanIP4New, Old IP: $WanIP4Cur"
            
            # Loop through each subdomain
            :foreach domain,params in=$CfApiRecords do={
                :local domainName $domain
                :local zoneID ($params->"zoneID")
                :local recordID ($params->"recordID")
                :log info "[script] Processing domain: $domainName"

                # If DNS updates are enabled
                :if ($CfApiUpdEnable = true) do={
                    # Construct API update URL
                    :local url "https://api.cloudflare.com/client/v4/zones/$zoneID/dns_records/$recordID/"
                    :log info "[script] Generated URL for DNS update: $url"
                    
                    # Check-certificate setting
                    :local CheckYesNo
                    :if ($CfApiCertCheck = true) do={ 
                        :set CheckYesNo "yes"; 
                    } else={ 
                        :set CheckYesNo "no"; 
                    }
                    :log info "[script] Certificate check set to: $CheckYesNo"

                    # Update DNS record
                    :log info "[script] Updating Cloudflare DNS record for $domainName..."
                    :local cfapi [/tool fetch http-method=put mode=https url=$url check-certificate=$CheckYesNo output=user as-value \
                    http-header-field="Authorization: Bearer $CfApiAuthToken,Content-Type: application/json" \
                    http-data="{\"type\":\"A\",\"name\":\"$domainName\",\"content\":\"$WanIP4New\",\"ttl\":1,\"proxied\":true}"]
                    :log warning "[script] Updated Cloudflare DNS record: $domainName -> $WanIP4New"
                }
            }

            # Update stored WAN IP variable
            :set WanIP4Cur $WanIP4New
        } else={
            :log info "[script] WAN IP has not changed. Current IP: $WanIP4New"
        }
    } else={
        :log error "[script] Failed to retrieve current WAN IP. Status: $result"
    }
} on-error={
    :log error "[script] Error occurred during Cloudflare DNS update process"
}
