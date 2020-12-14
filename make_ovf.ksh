#!/bin/ksh

## v2.5.1
########################################################################
## Copyright 2018 Skytap Inc.
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##     http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
########################################################################


## Creates AIX OVF file for import into Skytap cloud
## Pass desired physical volumes into script starting with rootvg's volume


########################################################################
## FIND AND DECLARE VARIABLES
########################################################################

set -A INPUT "$@"

WRKDIR=$WRKDIR

## Will set the imported VM name to be the same as the hostname
LPAR_NAME=$(hostname)

## Find number of virtual processors
VIRTUAL_PROCESSORS=$(prtconf | awk '/Number Of Processors/{print $4}')

## Find amount of allocated ram
RAM_ALLOCATION=$(lparstat -i | awk '/Online Memory/{print $4}')

## Find all in-use ethernet adapters
ETHERNET_ADAPTERS=$(netstat -i | awk '/en/{print $1}' | awk '!x[$0]++')

## Discover disks from input
for arg;do
  typeset -i DISK_ALLOCATION
   DISK_ALLOCATION=$(getconf DISK_SIZE /dev/$arg)
   if [ $? -ne 0 ]; then
      >&2 echo "FAILED: unable to detect device /dev/$arg, exiting script"
      exit 1 #exit script due to failure state, unable to find disk
  fi
done


########################################################################
## CREATE OVF FILE
########################################################################

echo ""
echo 'Creating OVF file: '$WRKDIR/$LPAR_NAME'.ovf'
> $WRKDIR/$LPAR_NAME'.ovf'
echo '<?xml version="1.0" encoding="UTF-8"?>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '<ovf:Envelope xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:skytap="http://help.skytap.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    <ovf:References>' >> $WRKDIR/$LPAR_NAME'.ovf'
for arg;do
   echo '        <ovf:File ovf:id="file_'$arg'" ovf:href="'$LPAR_NAME-$arg'.img"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
done
echo '    </ovf:References>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    <ovf:DiskSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '        <ovf:Info>Virtual disk information</ovf:Info>' >> $WRKDIR/$LPAR_NAME'.ovf'
for arg;do
   typeset -i DISK_ALLOCATION
   DISK_ALLOCATION=$(getconf DISK_SIZE /dev/$arg)*1024*1024
   echo '        <ovf:Disk ovf:fileRef="file_'$arg'" ovf:diskId="disk_'$arg'" ovf:capacity="'$DISK_ALLOCATION'"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
done
echo '    </ovf:DiskSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    <ovf:VirtualSystemCollection ovf:id="AIX">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '        <ovf:VirtualSystem ovf:id="AIX MachineName">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            <ovf:Name>'$LPAR_NAME'</ovf:Name>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            <ovf:OperatingSystemSection ovf:id="9">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ovf:Info/>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ovf:Description>AIX</ovf:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ns0:architecture xmlns:ns0="ibmpvc">ppc64</ns0:architecture>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            </ovf:OperatingSystemSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            <ovf:VirtualHardwareSection>' >> $WRKDIR/$LPAR_NAME'.ovf' >> $WRKDIR/$LPAR_NAME'.ovf'
typeset -i COUNT=1
for e in $ETHERNET_ADAPTERS;do
   SLOT=$(lsdev -l $(echo $e | sed 's/en/ent/') -F "physloc"| sed -n 's/.*-C\([^-]*\)-.*/\1/p')
   NETADDR=$(lsattr -E -l $e -a netaddr | awk '{print $2}')
   NETMASK=$(lsattr -E -l $e -a netmask | awk '{print $2}')
   echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:Description>Ethernet adapter '$COUNT'</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ElementName>Network adapter '$COUNT'</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:InstanceID>10'$COUNT'</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ResourceType>10</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
   if [ -n "$SLOT" ]; then
      echo '                    <skytap:Config skytap:value="'$SLOT'" skytap:key="slotInfo.cardSlotNumber"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   if [ -n "$NETADDR" ]; then
      echo '                    <skytap:Config skytap:value="'$NETADDR'" skytap:key="networkInterface.ipAddress"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   if [ -n "$NETMASK" ]; then
      echo '                    <skytap:Config skytap:value="'$NETMASK'" skytap:key="networkInterface.ipAddress"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   ((COUNT=COUNT+1))
done
typeset -i COUNT=1
for arg;do
   SLOT=$(lsdev -l $arg -F "physloc" | sed -n 's/.*-C\([^-]*\)-.*/\1/p')
   echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:Description>Hard disk</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ElementName>Hard disk '$COUNT'</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:HostResource>ovf:/disk/disk_'$arg'</rasd:HostResource>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:InstanceID>100'$COUNT'</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ResourceType>17</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
   if [ -n "$SLOT" ]; then
      echo '                    <skytap:Config skytap:value="'$SLOT'" skytap:key="slotInfo.cardSlotNumber"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   ((COUNT=COUNT+1))
done
echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Description>Number of Virtual CPUs</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ElementName>'$VIRTUAL_PROCESSORS' virtual CPU(s)</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:InstanceID>7</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Reservation>0</rasd:Reservation>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ResourceType>3</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:VirtualQuantity>'$VIRTUAL_PROCESSORS'</rasd:VirtualQuantity>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Weight>0</rasd:Weight>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Description>Memory Size</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ElementName>'$RAM_ALLOCATION' MB of memory</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:InstanceID>8</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Reservation>0</rasd:Reservation>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ResourceType>4</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:VirtualQuantity>'$RAM_ALLOCATION'</rasd:VirtualQuantity>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Weight>0</rasd:Weight>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            </ovf:VirtualHardwareSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '        </ovf:VirtualSystem>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    </ovf:VirtualSystemCollection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '</ovf:Envelope>' >> $WRKDIR/$LPAR_NAME'.ovf'

echo 'OVF Completed Successfully'
exit 0 #successful exit
