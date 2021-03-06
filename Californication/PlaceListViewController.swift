/**
 * Copyright (c) 2016 Ivan Magda
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import MBProgressHUD

// MARK: Constants

private let kSortingTypeIdentifier = "sortingType"

// MARK: Types

private enum SortingType: Int {
    case Name, Rating
}

// MARK: - PlaceListViewController: UIViewController

class PlaceListViewController: UIViewController {
    
    // MARK: Outlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortingButton: UIBarButtonItem!
    
    // MARK: Properties
    
    var didSelect: (Place) -> () = { _ in }
    var placeDirector: PlaceDirectorFacade!
    
    private var sortingType: SortingType {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            let value = defaults.integerForKey(kSortingTypeIdentifier)
            return SortingType(rawValue: value) ?? .Rating
        }
        
        set {
            NSUserDefaults.standardUserDefaults().setInteger(newValue.rawValue, forKey: kSortingTypeIdentifier)
        }
    }
    
    private let tableViewDataSource = PlaceListTableViewDataSource()
    private let refreshControl = UIRefreshControl()
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.sharedApplication().statusBarStyle = .LightContent
    }
    
    // MARK: Actions
    
    @IBAction func sortDidPressed(sender: AnyObject) {
        func didSelectSortingType(type: SortingType) {
            guard type != sortingType else { return }
            sortingType = type
            reloadData()
        }
        
        let actionController = UIAlertController(title: "Sorting", message: nil, preferredStyle: .ActionSheet)
        actionController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        actionController.addAction(UIAlertAction(title: "By name", style: .Default, handler: { action in
            didSelectSortingType(.Name)
        }))
        actionController.addAction(UIAlertAction(title: "By rating", style: .Default, handler: { action in
            didSelectSortingType(.Rating)
        }))
        
        presentViewController(actionController, animated: true, completion: nil)
    }
    
    // MARK: Configure
    
    private func setup() {
        configureTableView()
        
        if let places = placeDirector.persistedPlaces() {
            updateWithNewData(places)
        }
    }
    
    private func configureTableView() {
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 120
        tableView.dataSource = tableViewDataSource
        tableView.delegate = self
        
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(loadPlaces), forControlEvents: .ValueChanged)
    }
    
    // MARK: Data
    
    func loadPlaces() {
        startLoading()
        
        placeDirector.allPlaces({ [weak self] places in
            self?.didStopLoading()
            self?.placeDirector.savePlaces(places)
            self?.updateWithNewData(places)
        }) { [weak self] error in
            guard error == nil else {
                self?.didStopLoading()
                self?.presentAlertWithTitle("Error", message: error!.localizedDescription)
                return
            }
        }
    }
    
    private func updateWithNewData(places: [Place]) {
        tableViewDataSource.places = places
        reloadData()
    }
    
    private func reloadData() {
        sortPlaces()
        tableView.reloadData()
    }
    
    private func sortPlaces() {
        func sortByName() -> [Place] {
            return tableViewDataSource.places!.sort { $0.name < $1.name }
        }
        
        func sortByRating() -> [Place] {
            return sortByName().sort { $0.rating > $1.rating }
        }
        
        guard let _ = tableViewDataSource.places else { return }
        
        switch sortingType {
        case .Name:
            tableViewDataSource.places = sortByName()
        case .Rating:
            tableViewDataSource.places = sortByRating()
        }
    }
    
}

// MARK: - PlaceListViewController (UI Functions) -

extension PlaceListViewController {
    
    private func startLoading() {
        let progressHud = MBProgressHUD.showHUDAddedTo(view, animated: true)
        progressHud.label.text = "Loading"
        
        sortingButton.enabled = false
    }
    
    private func didStopLoading() {
        MBProgressHUD.hideHUDForView(view, animated: true)
        refreshControl.endRefreshing()
        
        sortingButton.enabled = true
    }
    
}

// MARK: - PlaceListViewController: UITableViewDelegate -

extension PlaceListViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let selectedPlace = tableViewDataSource.placeForIndexPath(indexPath) else {
            return
        }
        
        didSelect(selectedPlace)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
}
