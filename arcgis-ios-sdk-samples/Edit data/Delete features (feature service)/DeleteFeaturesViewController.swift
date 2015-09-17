// Copyright 2015 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

class DeleteFeaturesViewController: UIViewController, AGSMapViewTouchDelegate, AGSCalloutDelegate {
    
    @IBOutlet private var mapView:AGSMapView!
    
    private var featureTable:AGSServiceFeatureTable!
    private var featureLayer:AGSFeatureLayer!
    private var lastQuery:AGSCancellable!
    private var selectedFeature:AGSFeature!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //add the source code button item to the right of navigation bar
        (self.navigationItem.rightBarButtonItem as! SourceCodeBarButtonItem).filenames = ["DeleteFeaturesViewController"]
        
        //instantiate map with a basemap
        let map = AGSMap(basemap: AGSBasemap.streetsBasemap())
        //set initial viewpoint
        map.initialViewpoint = AGSViewpoint(center: AGSPoint(x: 544871.19, y: 6806138.66, spatialReference: AGSSpatialReference.webMercator()), scale: 2e6)
        
        //assign the map to the map view
        self.mapView.map = map
        //set touch delegate on map view as self
        self.mapView.touchDelegate = self
        
        //instantiate service feature table using the url to the service
        self.featureTable = AGSServiceFeatureTable(URL: NSURL(string: "http://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0"))
        //create a feature layer using the service feature table
        self.featureLayer = AGSFeatureLayer(featureTable: self.featureTable)
        
        //add the feature layer to the operational layers on map
        map.operationalLayers.addObject(featureLayer)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func showCallout(feature:AGSFeature, tapLocation:AGSPoint) {
        let title = feature.attributeValueForKey("typdamage") as! String
        self.mapView.callout.title = title
        self.mapView.callout.delegate = self
        self.mapView.callout.accessoryButtonImage = UIImage(named: "Discard")
        self.mapView.callout.showCalloutForFeature(feature, layer: self.featureLayer, tapLocation: tapLocation, animated: true)
    }
    
    func deleteFeature(feature:AGSFeature) {
        self.featureTable.deleteFeature(feature, completion: { (succeeded:Bool, error:NSError!) -> Void in
            if let error = error {
                println("Error while deleting feature : \(error.localizedDescription)")
            }
            else {
                self.applyEdits()
            }
        })
    }
    
    func applyEdits() {
        self.featureTable.applyEditsWithCompletion { [weak self] (featureEditResults: [AnyObject]!, error: NSError!) -> Void in
            if let error = error {
                SVProgressHUD.showErrorWithStatus("Error while applying edits :: \(error.localizedDescription)")
            }
            else {
                if let featureEditResults = featureEditResults where featureEditResults.count > 0 && featureEditResults[0].completedWithErrors == false {
                    SVProgressHUD.showSuccessWithStatus("Edits applied successfully")
                }
            }
        }
    }
    
    //MARK: - AGSMapViewTouchDelegate
    
    func mapView(mapView: AGSMapView!, didTapAtPoint screen: CGPoint, mapPoint mappoint: AGSPoint!) {
        if let lastQuery = self.lastQuery{
            lastQuery.cancel()
        }
        
        //hide the callout
        self.mapView.callout.dismiss()
        
        var tolerance:Double = 22
        var mapTolerance = tolerance * self.mapView.unitsPerPixel
        var env = AGSEnvelope(XMin: mappoint.x - mapTolerance,
            yMin: mappoint.y - mapTolerance,
            xMax: mappoint.x + mapTolerance,
            yMax: mappoint.y + mapTolerance,
            spatialReference: self.mapView.map!.spatialReference)
        
        var queryParams = AGSQueryParameters()
        queryParams.geometry = env
        queryParams.outFields = ["*"]
        
        self.lastQuery = self.featureTable.queryFeaturesWithParameters(queryParams, completion: { [weak self] (result:AGSFeatureQueryResult!, error:NSError!) -> Void in
            if let error = error {
                println(error)
            }
            else {
                if let feature = result.enumerator().nextObject() {
                    //show callout for the first feature
                    self?.showCallout(feature, tapLocation: mappoint)
                    //update selected feature
                    self?.selectedFeature = feature
                }
            }
        })
    }
    
    //MARK: - AGSCalloutDelegate
    
    func didTapAccessoryButtonForCallout(callout: AGSCallout) {
        //hide the callout
        self.mapView.callout.dismiss()
        
        //confirmation
        let alertController = UIAlertController(title: "Are you sure you want to delete the feature", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        //action for Yes
        let alertAction = UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default) { [weak self] (action:UIAlertAction!) -> Void in
            self?.deleteFeature(self!.selectedFeature)
        }
        alertController.addAction(alertAction)
        
        //action for cancel
        let cancelAlertAction = UIAlertAction(title: "No", style: UIAlertActionStyle.Cancel, handler: nil)
        alertController.addAction(cancelAlertAction)
        
        //present alert controller
        self.presentViewController(alertController, animated: true, completion: nil)
    }
}