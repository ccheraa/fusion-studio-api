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

import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

(:~
 : This script will be executed after your application
 : is copied into the database.
 :
 : You can perform any final cleanup that you
 : need in here. By default it just removes the copy
 : of collection.xconf from the app collection.
 :
 : The following external variables are set by the repo:deploy function
 :)

(: file path pointing to the exist installation directory :)
declare variable $home external;

(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;

(: the target collection into which the app is deployed :)
declare variable $target external;

(:
  collection configuration was copied to the system config collection by pre-install.xq
  so we can now remove it from the app colllection
:)
xmldb:remove($target, "collection.xconf")