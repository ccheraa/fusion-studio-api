(:
 : Fusion Studio API - API for Fusion Studio
 : Copyright © 2017 Evolved Binary (tech@evolvedbinary.com)
 :
 : This program is free software: you can redistribute it and/or modify
 : it under the terms of the GNU Affero General Public License as published by
 : the Free Software Foundation, either version 3 of the License, or
 : (at your option) any later version.
 :
 : This program is distributed in the hope that it will be useful,
 : but WITHOUT ANY WARRANTY; without even the implied warranty of
 : MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 : GNU Affero General Public License for more details.
 :
 : You should have received a copy of the GNU Affero General Public License
 : along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

module namespace sec = "http://fusiondb.com/ns/studio/api/security";

declare namespace array = "http://www.w3.org/2005/xpath-functions/array";

import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace util = "http://exist-db.org/xquery/util";


declare function sec:list-users() as array(xs:string) {
    array { sm:list-users() }
};

declare function sec:list-groups() as array(xs:string) {
    array { sm:list-groups() }
};

declare function sec:get-user($username as xs:string) as map(xs:string, item())? {
    if (sm:list-users() = $username)
    then
        map {
            "userName": $username,
            "enabled": sm:is-account-enabled($username),
            "expired": false(),
            "umask": sm:get-umask($username),
            "metadata": array {
                for $key in sm:get-account-metadata-keys($username)
                return
                    map {
                        "key": $key,
                        "value": sm:get-account-metadata($username, $key)
                    }
            },
            "primaryGroup": sm:get-user-primary-group($username),
            "groups": array { sm:get-user-groups($username) }
        }
    else ()
};


declare function sec:put-user($username as xs:string, $user-data as map(xs:string, item())) as xs:boolean {
    if (sm:user-exists($username)) 
    then
        sec:update-user($username, $user-data)
    else
        sec:create-user($username, $user-data)
        
};

declare
    %private
function sec:update-user($username, $user-data as map(xs:string, item())) as xs:boolean {
    if (not(empty($user-data?userName) and $username eq $user-data?userName))
    then
        (
        
            (: change password? :)
            if (not(empty($user-data?password)))
            then
                sm:passwd-hash($username, $user-data?password)
            else ()
            ,
            (: change primary group? :)
            if (not(empty($user-data?primaryGroup)))
            then
                sm:set-user-primary-group($username, $user-data?primaryGroup)
            else ()
            ,
            (: change groups? :)
            if (not(empty($user-data?groups)))
            then
                (
                    (: remove from existing groups (but not the primary group) :)
                    sm:get-user-groups($username)[. ne sm:get-user-primary-group($username)] ! sm:remove-group-member(., $username),
                    (: add to new groups (including the primary group) :)
                    (array:flatten($user-data?groups), sm:get-user-primary-group($username)) ! sm:add-group-member(., $username)
                )
            else (),
            
            (: change metadata? :)
            if (not(empty($user-data?metadata)))
            then
                (
                    sec:clear-account-metadata($username),
                    let $_ := array:for-each($user-data?metadata, function($attribute as map(xs:string, xs:string)) {
                        sm:set-account-metadata($username, $attribute?key, $attribute?value)
                    })
                    return ()
                )
            else (),

            (: change enabled/disabled? :)
            if (not(empty($user-data?enabled)))
            then
                sm:set-account-enabled($username, $user-data?enabled)
            else(),
            
            true() (: success :)
        )

    else
        false()
};

declare
    %private
function sec:clear-account-metadata($username as xs:string) as empty-sequence() {
    for $key in sm:get-account-metadata-keys()
    return
        sm:set-account-metadata($username, $key, "")    (: TODO - how to actually delete instead of setting to the empty string? :)
};

declare
    %private
function sec:create-user($username as xs:string, $user-data as map(xs:string, item())) as xs:boolean {
    if (not(empty($user-data?userName)) and ($username eq $user-data?userName) and not(empty($user-data?password)))
    then
        let $primary-group :=
            if (not(empty($user-data?primaryGroup)))
            then
                $user-data?primaryGroup
            else (
                    if (not(sm:group-exists($username)))
                    then
                        (: create primary group based on the username :)
                        let $_ := sm:create-group($username, "Personal group of " || $username) return ()
                    else (),
                    $username
                 )
        
        (:
         : NOTE - we first temporarily set the passwd to a UUID, as there is no way to set it when creating from a digest.
         : Next we update it to the real password digest
         :)
        let $_ := sm:create-account($username, util:uuid(), $primary-group, ($primary-group, array:flatten($user-data?groups)))
        let $_ := sm:passwd-hash($username, $user-data?password)
        let $_ :=
            if (not(empty($user-data?metadata)))
            then
                let $_ := array:for-each($user-data?metadata, function($attribute as map(xs:string, xs:string)) {
                    sm:set-account-metadata($username, $attribute?key, $attribute?value)
                })
                return ()
            else()
        let $_ :=
            if (not(empty($user-data?enabled)))
            then
                sm:set-account-enabled($username, $user-data?enabled)
            else()
        return
            true()
    else
        false()
};

declare function sec:delete-user($username as xs:string) {
    if (sm:list-users() = $username)
    then
        let $_ := sm:remove-account($username)
        return
            true()
    else
        false()
};

declare function sec:get-group($groupname as xs:string) as map(xs:string, item())? {
    if (sm:list-groups() = $groupname)
    then
        map {
            "groupName": $groupname,
            "metadata": array {
                for $key in sm:get-group-metadata-keys($groupname)
                return
                    map {
                        "key": $key,
                        "value": sm:get-group-metadata($groupname, $key)
                    }
            },
            "managers": array { sm:get-group-managers($groupname) }
        }
    else ()
};

declare function sec:put-group($groupname as xs:string, $group-data as map(xs:string, item())) as xs:boolean {
    if (sm:group-exists($groupname)) 
    then
        sec:update-group($groupname, $group-data)
    else
        sec:create-group($groupname, $group-data)
        
};

declare
    %private
function sec:update-group($groupname, $group-data as map(xs:string, item())) as xs:boolean {
    if (not(empty($group-data?groupName) and $groupname eq $group-data?groupName))
    then
        (
            (: change managers? :)
            let $new-managers := array:flatten($group-data?managers)
            return
                if (not(empty($new-managers)))
                then
                    let $existing-managers := sm:get-group-managers($groupname)
                    let $managers-to-remove := $existing-managers[not( . = $new-managers)]
                    let $managers-to-add := $new-managers[not(. = $existing-managers)]
                    return
                    (
                        (: remove from existing group managers :)
                        $managers-to-remove ! sm:remove-group-manager($groupname, .),

                        (: add to new managers :)
                        $managers-to-add ! sm:add-group-manager($groupname, .)
                    )
                else ()
            ,
            
            (: change metadata? :)
            if (not(empty($group-data?metadata)))
            then
                (
                    sec:clear-group-metadata($groupname),
                    let $_ := array:for-each($group-data?metadata, function($attribute as map(xs:string, xs:string)) {
                        sm:set-group-metadata($groupname, $attribute?key, $attribute?value)
                    })
                    return ()
                )
            else (),
            
            true() (: success :)
        )

    else
        false()
};

declare
    %private
function sec:clear-group-metadata($groupname as xs:string) as empty-sequence() {
    for $key in sm:get-group-metadata-keys()
    return
        sm:set-group-metadata($groupname, $key, "")    (: TODO - how to actually delete instead of setting to the empty string? :)
};

declare
    %private
function sec:create-group($groupname as xs:string, $group-data as map(xs:string, item())) as xs:boolean {
    if (not(empty($group-data?groupName)) and ($groupname eq $group-data?groupName))
    then
        let $current-user := sm:id()/sm:id/sm:real/sm:username
        let $description := ($group-data?description, "")[1]
        let $_ := sm:create-group($groupname, ($current-user, array:flatten($group-data?managers)), $description)
        return
            if (not(empty($group-data?metadata)))
            then
                (
                    let $_ := array:for-each($group-data?metadata, function($attribute as map(xs:string, xs:string)) {
                        sm:set-group-metadata($groupname, $attribute?key, $attribute?value)
                    })
                    return ()
                    ,
                    true()
                )
            else
                true()
    else
        false()
};

declare function sec:delete-group($groupname as xs:string) {
    if (sm:list-groups() = $groupname)
    then
        let $_ := sm:remove-group($groupname)
        return
            true()
    else
        false()
};

