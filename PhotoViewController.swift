//
//  PhotoViewController.swift
//  Virtual Tourist
//
//  Created by 政达 何 on 2017/1/17.
//  Copyright © 2017年 政达 何. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoViewController: UIViewController,MKMapViewDelegate,UICollectionViewDelegate,UICollectionViewDataSource {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var newButton: UIButton!
    
    var pin: Pin?
    let flickr = FlickrClient.sharedInstance()
    let delegate = UIApplication.shared.delegate as! AppDelegate
    let numOfImageDisplay = 10
    var insertIndexCache: [NSIndexPath]!
    var deleteIndexCache: [NSIndexPath]!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
    
    func initializeFlowLayout()
    {
        // For the image to scale properly.
        collectionView?.contentMode = UIViewContentMode.scaleAspectFit
        collectionView?.backgroundColor = UIColor.white
        let space : CGFloat = 0.5
        //decide the dimension based on the orientation of the device.
        let dimension = (self.view.frame.width - (2 * space)) / 2.5
        collectionViewFlowLayout.minimumInteritemSpacing = space
        collectionViewFlowLayout.minimumLineSpacing = space
        collectionViewFlowLayout.itemSize = CGSize(width: dimension, height: dimension)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        let annotation = MKPointAnnotation()
        annotation.coordinate.latitude = (pin!.lat)
        annotation.coordinate.longitude = (pin!.lot)
        mapView.addAnnotation(annotation)
        initializeFlowLayout()
        if loadPhotosFromDatabase().count == 0 {
        searchPhoto()
        }
        mapView.centerCoordinate = (pin?.coordinate)!
        mapView.camera.altitude = 100
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        delegate.stack.save()
    }
    
    @IBAction func newCollection(_ sender: Any) {
        deleteAll()
        searchPhoto()
    }
    
    func deleteAll(){
        for photo in fetchedResultsController?.fetchedObjects as! [Photo] {
             delegate.stack.context.delete(photo)
        }
 //       delegate.stack.save()
    }
    var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>? {
        didSet {
            fetchedResultsController?.delegate = self
            executeSearch()
            collectionView.reloadData()
        }
    }

    func loadPhotosFromDatabase() -> [Photo]{
        var photos = [Photo]()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "photo = %@", pin!)
        fetchRequest.sortDescriptors = []
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: delegate.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController?.delegate = self
        
        do
        {
            try fetchedResultsController?.performFetch()
            if let result = fetchedResultsController?.fetchedObjects as? [Photo]{
                photos = result
            }
        }catch{
            print("error fetch photos")
        }
        return photos
    }
    
    func searchPhoto(){
        flickr.getImageURL((pin!.lat), lon: pin!.lot){ (data,error) in
            if let photos = data!["photos"] as! [String:Any]? {
                if let photo = photos["photo"] as! Array<Any>?{
                    let count = photo.count
                    guard count != 0 else{
                        return
                    }
                    let urlIndex  =  self.shuffleArray(Array(0...(count - 1)))
                    let range = count < self.numOfImageDisplay ? count : self.numOfImageDisplay
                    let selectedURL = Array(urlIndex.prefix(range))
                    var url = [String]()
                    for item in selectedURL{
                        let temp = photo[item] as! [String:Any]
                        url.append(temp["url_m"] as! String)
                        self.collectionView.updateConstraints()
                    }
                    for item in url{
                        let photo = Photo(context: self.delegate.stack.context)
                        photo.photo = self.pin
                        photo.url = item
                    }}}else{
                print(error!)
            }
        }
    }
    
   private func shuffleArray<T>(_ array: Array<T>) -> Array<T>
    {
        var array = array
        for index in ((0 + 1)...array.count - 1).reversed()
        {
            let j = Int(arc4random_uniform(UInt32(index-1)))
            swap(&array[index], &array[j])
        }
        return array
    }
    

}
extension PhotoViewController {
    func executeSearch() {
        if let fc = fetchedResultsController {
            do {
                try fc.performFetch()
            } catch let e as NSError {
                print("Error while trying to perform a search: \n\(e)\n\(fetchedResultsController)")
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let photo = fetchedResultsController?.object(at: indexPath) as! Photo
        delegate.stack.context.delete(photo)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
         return fetchedResultsController!.sections![section].numberOfObjects
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.activityIndicator.isHidden = true
        cell.imageView.image = nil
        let photo = fetchedResultsController?.object(at: indexPath) as! Photo
        if photo.imageData == nil{
            cell.activityIndicator.isHidden = false
            cell.activityIndicator.startAnimating()
            DispatchQueue.main.async{
            self.flickr.downloadPhotos(photo.url!){ (image, error) in
            photo.imageData = image
            cell.imageView.image = UIImage(data: image as! Data)
            cell.activityIndicator.isHidden = true
            }
            }
        }else{
            cell.imageView.image = UIImage(data: photo.imageData as! Data)
        }
    return cell
    }
    
    
}

extension PhotoViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        insertIndexCache = [NSIndexPath]()
        deleteIndexCache = [NSIndexPath]()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        collectionView.performBatchUpdates(
            {
                self.collectionView.insertItems(at: self.insertIndexCache as [IndexPath])
                self.collectionView.deleteItems(at: self.deleteIndexCache as [IndexPath])
        }, completion: nil)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        switch type
        {
        case .insert:   insertIndexCache.append(newIndexPath! as NSIndexPath)
        case .delete:   deleteIndexCache.append(indexPath! as NSIndexPath)
        default: break
        }
    }
}

