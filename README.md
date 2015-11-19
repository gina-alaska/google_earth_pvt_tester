# google_earth_pvt_tester
A simple tool to test wms feeds in google earth as a proxy for the pvt

This helper tool was built to assist in the debugging the optmization of WMS feeds for usin in the University of Alaska Anchorage Planetarium's Visualization Theature (UAA-PVT).

The UAA Planetarium Visualization Theature (PVT) uses (insert name of the software here) to provide a a GIS 


#how to use it..
If you are on a mac..
* install ruby (I suggest using rbenv using homebrew)
** brew install rbenv ruby-build
** rbenv install 2.2.0
	
* clone git repo
** cd 
** mkdir gits
** cd gits
** git clone https://github.com/gina-alaska/google_earth_pvt_tester.git
** cd google_earth_pvt_tester
* install ruby bits
** gem install bundler 
** bundle install 
* run the app
** rackup -p 2000  -s puma  kml_relay.ru
* point your webbrowser at localhost:2000/relay/ , select a kml feed, and begin!

# authors / contributors
?
* Jay Cable - UAF GINA
