/*
 *    GroupBot.vala
 *
 *    Copyright (C) 2013-2014  Venom authors and contributors
 *
 *    This file is part of Venom.
 *
 *    Venom is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    Venom is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with Venom.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Testing {
  public class GroupBot : GLib.Object {
    private Tox.Tox tox;
    private int groupchat_number = 0;
    public GroupBot( bool ipv6 = false ) {
      tox = new Tox.Tox(ipv6 ? 1 : 0);
      tox.callback_friend_request(on_friend_request);
      tox.callback_friend_message(on_friend_message);
      tox.callback_group_message(on_groupchat_message);
      tox.callback_group_namelist_change(on_group_namelist_change);
    }

    private void on_groupchat_message(Tox.Tox tox, int groupnumber, int friendgroupnumber, uint8[] message) {
      uint8[] name_buf = new uint8[Tox.MAX_NAME_LENGTH];
      if( tox.group_peername(groupnumber, friendgroupnumber, name_buf) < 0 ) {
        stderr.printf("[ERR] Could not get name for peer #%i\n", friendgroupnumber);
      }
      string friend_name = (string)name_buf;
      stdout.printf("[GM ] %s: %s\n", friend_name, (string)message);
    }

    private void on_group_namelist_change(Tox.Tox tox, int groupnumber, int peernumber, Tox.ChatChange change) {
      if(change == Tox.ChatChange.PEER_ADD || change == Tox.ChatChange.PEER_DEL) {
        stdout.printf("[LOG] Peer connected/disconnect, updating status message\n");
        update_status_message();
      }
    }

    private void on_friend_request(uint8[] key, uint8[] data) {
      uint8[] public_key = Venom.Tools.clone(key, Tox.CLIENT_ID_SIZE);
      stdout.printf("[LOG] Friend request from %s received.\n", Venom.Tools.bin_to_hexstring(public_key));
      Tox.FriendAddError friend_number = tox.add_friend_norequest(public_key);
      if(friend_number < 0) {
        stderr.printf("[ERR] Friend could not be added :%s\n", Venom.Tools.friend_add_error_to_string(friend_number));
      }
    }

    private void on_friend_message(Tox.Tox tox, int friend_number, uint8[] message) {
      uint8[] name_buf = new uint8[Tox.MAX_NAME_LENGTH];
      if( tox.get_name(friend_number, name_buf) < 0) {
        stderr.printf("[ERR] Could not get name for friend #%i\n", friend_number);
      }
      string name = (string) name_buf;
      string message_str = (string) message;
      stdout.printf("[PM ] %s: %s\n", name, message_str);

      if(message_str == "invite") {
        stdout.printf("[LOG] Inviting '%s' to groupchat #%i\n", name, groupchat_number);
        if(tox.invite_friend(friend_number, groupchat_number) != 0) {
          stderr.printf("[ERR] Failed to invite '%s' to groupchat #%i\n", name, groupchat_number);
        }
      }
    }

    private void update_status_message() {
      int group_number_peers = tox.group_number_peers(groupchat_number);
      string status_message = "send me 'invite' to get invited to groupchat (%i online)".printf(group_number_peers);
      if(group_number_peers < 0 || tox.set_status_message(Venom.Tools.string_to_nullterm_uint(status_message)) < 0) {
        stderr.printf("[ERR] Setting status message failed.\n");
      }
    }

    public void run(string ip_string, string pub_key_string, int port = 33445, bool ipv6 = true) {
      tox.bootstrap_from_address(ip_string,
          ipv6 ? 1 : 0,
          ((uint16)port).to_big_endian(),
          Venom.Tools.hexstring_to_bin(pub_key_string)
      );

      uint8[] buf = new uint8[Tox.FRIEND_ADDRESS_SIZE];
      tox.get_address(buf);
      stdout.printf("[LOG] Tox ID: %s\n", Venom.Tools.bin_to_hexstring(buf));

      if(tox.set_name(Venom.Tools.string_to_nullterm_uint("Group bot")) != 0) {
        stderr.printf("[ERR] Setting user name failed.\n");
      }

      groupchat_number = tox.add_groupchat();
      if(groupchat_number < 0) {
        stderr.printf("[ERR] Creating a new groupchat failed.\n");
      } else {
        stdout.printf("[LOG] Created new groupchat #%i\n", groupchat_number);
      }

      update_status_message();

      bool connection_status = false;
      bool running = true;
      while( running ) {
        bool new_connection_status = (tox.isconnected() != 0);
        if(new_connection_status != connection_status) {
          connection_status = new_connection_status;
          if(connection_status)
            stdout.printf("[LOG] Connected to DHT.\n");
          else
            stdout.printf("[LOG] Connection to DHT lost.\n");
        }

        tox.do();
        Thread.usleep(25000);
      }
    }

    public static void main(string[] args) {
      GroupBot bot = new GroupBot();
      bot.run("192.254.75.98", "FE3914F4616E227F29B2103450D6B55A836AD4BD23F97144E2C4ABE8D504FE1B");
    }
  }
}
