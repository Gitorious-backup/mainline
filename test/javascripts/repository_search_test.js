/*
  #--
  #   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
  #
  #   This program is free software: you can redistribute it and/or modify
  #   it under the terms of the GNU Affero General Public License as published by
  #   the Free Software Foundation, either version 3 of the License, or
  #   (at your option) any later version.
  #
  #   This program is distributed in the hope that it will be useful,
  #   but WITHOUT ANY WARRANTY; without even the implied warranty of
  #   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  #   GNU Affero General Public License for more details.
  #
  #   You should have received a copy of the GNU Affero General Public License
  #   along with this program.  If not, see <http://www.gnu.org/licenses/>.
  #-- 
*/

TestCase("Live search for repositories", {
    "test should create the container if it doesn't exist": function() {
        /*:DOC += <div id="repo_search"><input type="text" /></div>*/
        jQuery("#repo_search").liveSearch();
        assertEquals(1, jQuery("#repo_search").find(".live-search-results").length);
    },

    "test should not create the container if it exists": function() {
        /*:DOC += <div id="repo_search"><ol class="live-search-results"></ol></div> */
        jQuery("#repo_search").liveSearch();
        assertEquals(1, jQuery("#repo_search").find(".live-search-results").length);        
    },

    "test should allow a custom result container": function() {
        /*:DOC += <div id="repo_search"><ol class="results"></ol></div> */
        jQuery("#repo_search").liveSearch({resultContainer: ".results"});
        assertEquals(1, jQuery("#repo_search").find(".results").length);
    },

    "test should do nothing if the selector doesn't exist": function() {
        /*:DOC += <div id="repo_search"></div>*/
        jQuery("#search").liveSearch();
        assertEquals(0, jQuery(".live-search-results").length);
    },

    "test should hide the result container": function() {
        /*:DOC += <div id="repo_search"></div>*/
        jQuery("#search").liveSearch();
        assertEquals(jQuery("#repo_search .live-search-results:hidden").length);
    },


    "test should call the backend's get when searching": function() {
        /*:DOC += <div id="repo_search"></div>*/
        var result;
        var backend = {
            get: function(uri, phrase, callback) {
                result = phrase;
            }
        };
        var api = jQuery("#search").liveSearch(backend, {resourceUri: "/repositories"});
        api.performSearch("Foo");
        assertEquals("Foo", result);
    },

    "test should append search results to result container": function() {
        /*:DOC += <div id="repo_search"></div>*/
        var backend = {
            get: function(uri, phrase, callback) {
                result = [{"description":"The mainline","name":"gitorious", 
                           "uri": "/gitorious/mainline", "owner":"hackers"}];
                callback(result);
            }
        };        
        var api = jQuery("#repo_search").liveSearch(backend, {resourceUri: "/repositories", 
                                                              itemClass: "item"});
        api.performSearch("Foo");
        assertEquals(1, jQuery("#repo_search .item").length);
    },

    "test should handle non-JSON or invalid responses": function (){
        /*:DOC += <div id="repo_search"></div>*/
        var backend = {
            get: function(uri, phrase, callback) {
                callback("This isn't JSON, is it?");
            }
        };
        var api = jQuery("#repo_search").liveSearch(backend, {
            resourceUri: "/repositories"
        });
        assertThrows(TypeError, function (){
            api.performSearch("testing");
        })
    },
    "test should use the renderer": function () {
    }
});