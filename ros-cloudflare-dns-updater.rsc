##  <<  For parameters'details see README.md @ https://github.com/bajodel/mikrotik-cloudflare-dns  >>

## ---- Configuration/Start  -----

# Define here single/multiple Dns Records (FQDNs) with their Zone IDs, Record IDs, and AuthTokens
# (hint: populate at least the first (single record to update), uncomment the second one or create more as needed)
# Optional per-record fields: "TTL" (default: 60) and "Proxied" (default: "false")
:local ParamVect {
                  "_____mywanip1_domain_com_____"={
      "DnsZoneID"="__Cloudflare_Dns_Zone_ID1____";
      "DnsRcrdID"="__Cloudflare_Dns_Record_ID1__";
      "AuthToken"="_Cloudflare_Auth_Key_Token_1_";
      "TTL"="60";
      "Proxied"="false";
  };
#                 "_____mywanip2_domain_com_____"={
#     "DnsZoneID"="__Cloudflare_Dns_Zone_ID2____";
#     "DnsRcrdID"="__Cloudflare_Dns_Record_ID2__";
#     "AuthToken"="_Cloudflare_Auth_Key_Token_2_";
#     "TTL"="120";
#     "Proxied"="true";
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
  # retrieve current WAN IPv4 (with fallback services)
  :local CFWanIP4New ""
  :local ipServices {"http://checkip.amazonaws.com/";"https://api.ipify.org/";"https://ifconfig.me/ip"}
  :foreach svcUrl in=$ipServices do={
    :if ($CFWanIP4New = "") do={
      :do {
        :local ChkIpResult [:tool fetch url=$svcUrl as-value output=user]
        :if ($ChkIpResult->"status" = "finished") do={
          :local rawData ($ChkIpResult->"data")
          :local rawLen [:len $rawData]
          # strip trailing newline/carriage-return if present
          :while ($rawLen > 0 && ([:pick $rawData ($rawLen - 1)] = "\n" || [:pick $rawData ($rawLen - 1)] = "\r")) do={
            :set rawData [:pick $rawData 0 ($rawLen - 1)]
            :set rawLen [:len $rawData]
          }
          :set CFWanIP4New $rawData
          :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Got WAN IP from $svcUrl -> $CFWanIP4New" }
        }
      } on-error={
        :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Failed to reach $svcUrl, trying next..." }
      }
    }
  }
  # did we succeed in getting our Wan IPv4?
  :if ($CFWanIP4New = "") do={
    :log warning "[CFUpdate script] No Wan IPv4 from any service, will retry on next run"
  } else={
    :if ($CFWanIP4New != $CFWanIP4Cur) do={
      # validate the new retrieved Wan IPv4
      :local CFWanIPv4IsValid false
      :do {
        :local testIP [:toip $CFWanIP4New]
        :set CFWanIPv4IsValid true
      } on-error={ :set CFWanIPv4IsValid false }
      # proceed if Wan IPv4 is valid, skip update and log error if not valid
      :if ($CFWanIPv4IsValid) do={
        :if ($VerboseLog = true) do={ :log info "[CFUpdate script] New Wan IPv4 is valid ($CFWanIP4New)" }
        # Wan IP changed (valid and different from previously stored one)
        :log warning "[CFUpdate script] Wan IPv4 changed -> New IPv4: $CFWanIP4New - Old IPv4: $CFWanIP4Cur"
        # if not in "Test Mode" proceed with Cloudflare DNS update
        :if ($TestMode = false) do={
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
          # evaluating "check-certificate" (yes/no)
          :local CheckYesNo
          :if ($CertCheck = true) do={ :set CheckYesNo "yes" } else={ :set CheckYesNo "no" }
          # track if all record updates succeed
          :local allUpdatesOK true
          # loop through each DNS Record Names provided
          :foreach fqdn,params in=$ParamVect do={
            :local DnsRcName $fqdn
            :local DnsZoneID ($params->"DnsZoneID")
            :local DnsRcrdID ($params->"DnsRcrdID")
            :local AuthToken ($params->"AuthToken")
            # get per-record TTL (default: 60)
            :local RecordTTL "60"
            :do { :set RecordTTL ($params->"TTL") } on-error={}
            :if ($RecordTTL = "") do={ :set RecordTTL "60" }
            # get per-record Proxied (default: false)
            :local RecordProxied "false"
            :do { :set RecordProxied ($params->"Proxied") } on-error={}
            :if ($RecordProxied = "") do={ :set RecordProxied "false" }
            :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Preparing CF-DNS-Update for <$DnsRcName> (TTL=$RecordTTL, Proxied=$RecordProxied)" }
            # create API update url for DNS Zone/Record
            :local url "https://api.cloudflare.com/client/v4/zones/$DnsZoneID/dns_records/$DnsRcrdID/"
            :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Generated URL for DNS update: $url" }
            :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Certificate check is globally set to $CertCheck" }
            # updating the Cloudflare DNS Record
            :do {
              :local CfApiResult [/tool fetch http-method=put mode=https url=$url check-certificate=$CheckYesNo output=user as-value \
              http-header-field="Authorization: Bearer $AuthToken,Content-Type: application/json" \
              http-data="{\"type\":\"A\",\"name\":\"$DnsRcName\",\"content\":\"$CFWanIP4New\",\"ttl\":$RecordTTL,\"proxied\":$RecordProxied,\"comment\":\"$CFComment\"}"]
              :if ($CfApiResult->"status" = "finished") do={
                :log warning "[CFUpdate script] Updated Cloudflare DNS record for <$DnsRcName> to $CFWanIP4New"
              } else={
                :log error "[CFUpdate script] Error occurred updating Cloudflare DNS record for <$DnsRcName> to $CFWanIP4New"
                :set allUpdatesOK false
              }
            } on-error={
              :log error "[CFUpdate script] Exception updating Cloudflare DNS record for <$DnsRcName>"
              :set allUpdatesOK false
            }
            # pause a little bit before the next one
            :delay 1
          }
          # only update stored IP if ALL records updated successfully (partial failure = retry next run)
          :if ($allUpdatesOK) do={
            :set CFWanIP4Cur $CFWanIP4New
          } else={
            :log warning "[CFUpdate script] Some records failed to update, will retry on next run"
          }
        } else={
          # test mode: still update the stored IP
          :set CFWanIP4Cur $CFWanIP4New
        }
      } else={ :log error "[CFUpdate script] Error occurred, retrieved Wan IPv4 is invalid ($CFWanIP4New)" }
    } else={ :if ($VerboseLog = true) do={ :log info "[CFUpdate script] Wan IPv4 did not change ($CFWanIP4New)" } }
  }
} on-error={ :log error "[CFUpdate script] Error occurred during Cloudflare DNS update process" }
