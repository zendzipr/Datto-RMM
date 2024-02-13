#!/bin/bash

# Monitors if NTP or Chrony is running and synchonized.
#
# Copyright (C) 2024  Peter Zendzian <zendzipr@gmail.com>
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Function to check NTP synchronization status with ntpd
check_ntp() {
    if pgrep ntpd > /dev/null; then
        echo "NTPD service detected."
        if ntpq -pn | grep -q '^*'; then
            echo "Time is synchronized with ntpd."
            exit 0
        else
            echo "Time is NOT synchronized with ntpd."
            exit 1
        fi
    else
        echo "NTPD service is not running."
    fi
}


# Function to check NTP synchronization status with chronyd using System time offset and Stratum
check_chrony() {
    if pgrep chronyd > /dev/null; then
        echo "Chrony service detected."
        # Get the absolute value of System time offset
        local system_time_offset=$(chronyc tracking | grep 'System time' | awk '{print $4}' | sed 's/^-//')
        # Get the Stratum level
        local stratum=$(chronyc tracking | grep 'Stratum' | awk '{print $3}')
        local threshold=0.005 # Define threshold (5 milliseconds)
        
        # Check if Stratum is not 0 and System time offset is less than or equal to threshold
        if [[ "$stratum" -ne 0 && $(echo "$system_time_offset <= $threshold" | bc -l) -eq 1 ]]; then
            echo "Time is closely synchronized with chrony (Stratum: $stratum, offset: $system_time_offset seconds)."
            exit 0
        else
            if [[ "$stratum" -eq 0 ]]; then
                echo "Stratum is 0, indicating chrony is not properly synchronized."
            else
                echo "Time is NOT closely synchronized with chrony (Stratum: $stratum, offset: $system_time_offset seconds)."
            fi
            exit 1
        fi
    else
        echo "Chrony service is not running."
    fi
}

# Check for ntpd and chronyd
check_ntp
check_chrony

# If neither ntpd nor chronyd are found or running properly, report an error.
echo "No NTP service detected or not running properly."
exit 1
