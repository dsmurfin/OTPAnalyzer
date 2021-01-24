//
//  ProducerController.swift
//
//  Copyright (c) 2020 Daniel Murfin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Cocoa
import OTPKit
import NetUtils

/**
 Producer Controller Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol ProducerControllerDelegate: AnyObject {
    
    /**
     Notifies the delegate that this view controller is about to close.
     
     - Parameters:
        - viewController: The view controller being closed.
     
    */
    func closingProducerController(_ viewController: ProducerController)
    
    /**
     Notifies the delegate that this producer was started.
    */
    func startedProducer()
    
    /**
     Notifies the delegate that this producer was stopped.
    */
    func stoppedProducer()
    
}

// MARK: -
// MARK: -

/**
 Producer Controller
 
 Creates and displays a new Producer.

*/

class ProducerController: NSViewController {
    
    /// Displays the consumers discovered by this producer.
    @IBOutlet var consumersTableView: NSTableView!
    
    /// Displays the points assigned to this producer.
    @IBOutlet var pointsCollectionView: NSCollectionView!

    /// Displays logs from this producer.
    @IBOutlet var logging: NSTextView!

    /// Used for the human-readable name of this producer.
    @IBOutlet var name: NSTextField!
    
    /// Used for selection of the Internet Protocol mode of this producer.
    @IBOutlet var ipMode: NSPopUpButton!
    
    /// Used for selection of the interface this producer should send/receive on.
    @IBOutlet var interface: NSPopUpButton!
    
    /// Used for selection of the default priority this producer should use for all points.
    @IBOutlet var priority: NSPopUpButton!
    
    /// Used for selection of the interval this producer should use for transmitting transform messages.
    @IBOutlet var interval: NSPopUpButton!
    
    /// Used for resetting the producer.
    @IBOutlet var reset: NSButton!
    
    /// Used for the selection of error logging for this producer.
    @IBOutlet var logErrors: NSButton!
    
    /// Used for the selection of debug logging for this producer.
    @IBOutlet var logDebug: NSButton!
    
    /// Used for the selection of socket logging for this producer.
    @IBOutlet var logDebugSocket: NSButton!
    
    /// Used for starting and stopping this producer.
    @IBOutlet var startStopButton: NSButton!
    
    /// Used for adding points to this producer.
    @IBOutlet var addPointButton: NSButton!
    
    /// The producer view model for this controller.
    let viewModel = ProducerModel()
    
    /// An array of network interfaces.
    private var interfaces = [Interface]()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        viewModel.modelDelegate = self
                
        // prepare any text fields
        prepareTextFields()
        
        // prepare any popups
        preparePopups()
        
        // disable buttons
        addPointButton.isEnabled = false
        reset.isEnabled = false
        
        // configure the collection view
        configureCollectionView()
        
        // this controller should receive log notifications
        viewModel.log.delegate = self
        viewModel.log.addVersion()
        
    }
    
    override func viewWillAppear() {
        
        super.viewWillAppear()
        
        // register to receive window delegate calls
        view.window?.delegate = self
        
        view.window?.title = "OTP Producer {\(viewModel.identifierCid.uuidString)}"
        
    }
    
    /**
     Configure the collection view for displaying points.
    */
    private func configureCollectionView() {
        
        // the collection view should look at this controller for its data source and delegate
        pointsCollectionView.dataSource = self
        
        // do not allow selection
        pointsCollectionView.isSelectable = false
        pointsCollectionView.allowsEmptySelection = false
        pointsCollectionView.allowsMultipleSelection = false
        
        // register the item to be displayed
        pointsCollectionView.register(NSNib(nibNamed: ProducerPointItem.nibName, bundle: nil), forItemWithIdentifier: ProducerPointItem.identifier)
        
        configureCollectionViewFlowLayout()
        
    }
    
    /**
     Configure the layout of the collection view.
    */
    func configureCollectionViewFlowLayout() {
        
        let flowLayout = NSCollectionViewFlowLayout()
        
        // the minimum space between items
        flowLayout.minimumInteritemSpacing = 10.0
        flowLayout.minimumLineSpacing = 10.0
        
        // the space between sections
        flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        
        // the item size
        flowLayout.itemSize = ProducerPointItem.itemSize
        
        pointsCollectionView.collectionViewLayout = flowLayout
        
    }
    
    /**
     Prepares the user interface for text fields.
    */
    private func prepareTextFields() {
        
        // add a name
        name.stringValue = "OTPAnalyzerProducer"
        
    }
    
    /**
     Prepares the user interface for all popups.
    */
    private func preparePopups() {
        
        // add titles for all IP Mode cases
        ipMode.removeAllItems()
        ipMode.addItems(withTitles: OTPIPMode.titles)
        
        // select OTP-4
        ipMode.selectItem(at: 0)
        
        // add titles for all priorities
        priority.removeAllItems()
        priority.addItems(withTitles: ProducerModel.priorities.map { "\($0)" })
        
        // select the default priority
        priority.selectItem(at: 100)
        
        // add titles for all intervals
        interval.removeAllItems()
        interval.addItems(withTitles: ProducerModel.transformIntervals.map { "\($0) ms" })
        
        // select the default interval
        interval.selectItem(at: 50-1)
        
    }
    
    /**
     Prepares the user interface for all popups.
    */
    private func prepareInterfacesPopup() {
        
        // remove all existing items
        interface.removeAllItems()

        var titles = [(title: String, shortTitle: String)]()
        for interface in interfaces {
            
            if let existingIndex = titles.firstIndex(where: { $0.shortTitle == interface.name }) {
                
                // this interface name already exists, so add the new address to it
                let newTitle = titles[existingIndex].title + ", \(interface.address ?? "??")"
                titles[existingIndex].title = newTitle
                
            } else {
                
                // this interface name is new, so add its title and the address
                let newInterface = (title: "\(interface.name) | \(interface.address ?? "??")", shortTitle: interface.name)
                titles.append(newInterface)
                
            }
            
        }

        // loop through all titles
        for title in titles {
            
            // create a menu item with the title, and a represented object with the short title for close popups
            let menuItem = NSMenuItem(title: title.title, action: nil, keyEquivalent: "")
            menuItem.representedObject = [ShortTitleCell.shortTitle:title.shortTitle]
            interface.menu?.addItem(menuItem)
            
        }
        
        // if an interface was previously selected, and is it still available, select it
        if let interfaceName = viewModel.interfaceName, let selectedIndex = titles.firstIndex(where: { $0.shortTitle == interfaceName }) {
            interface.selectItem(at: selectedIndex)
        } else if let interface = interfaces.first {
            // the first interface found should be used
            viewModel.interfaceName = interface.name
        }
        
    }
    
    /**
     Calculates the selected priority.
     
     - Returns: The selected priority.
     
    */
    private func selectedPriority() -> UInt8 {
        ProducerModel.priorities[priority.indexOfSelectedItem]
    }

    /**
     Called whenever interfaces have been discovered.
    */
    func discovered(interfaces: [Interface]) {

        if let interfaceName = viewModel.interfaceName, viewModel.started, !interfaces.contains(where: { $0.name == interfaceName }) {
            
            // the interface selected no longer exists, so stop this producer
            viewModel.stopProducer()
            
        }
        
        // update discovered interfaces
        self.interfaces = interfaces
        
        // add titles for all interfaces
        prepareInterfacesPopup()
        
    }
    
    /**
     Stops this producer and optionally dismisses the view controller.
     
     - Parameters:
         - close: Whether the controller should be closed after stopping this producer.
     
    */
    func stop(close: Bool) {

        // stop the producer
        if viewModel.started {
            startStopProducer(self)
        }
        
        // close if requested
        if close {
            view.window?.close()
        }
        
    }
    
    /**
     Called when a new view controller is presented via a segue.
    */
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        // get the destination controller
        guard let controller = segue.destinationController as? AddPointController else { return }

        // provide any variables to the controller
        controller.producerPriority = selectedPriority()
        controller.existingPoints = viewModel.points
        
        // register to receive add point controller notifications
        controller.delegate = self
        
    }

    /**
     Starts the producer sending network data.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func startStopProducer(_ sender: AnyObject) {
        
        if viewModel.started {
        
            // attempt to stop the producer
            viewModel.stopProducer()

        } else {
            
            // start the producer
            
            // get the priority
            let priority = selectedPriority()
            
            // get the interval
            let interval = ProducerModel.transformIntervals[self.interval.indexOfSelectedItem]
            
            // get the ip mode
            let ipMode = OTPIPMode.allCases[self.ipMode.indexOfSelectedItem]
            
            // attempt to start the producer
            viewModel.startProducer(name: name.stringValue, ipMode: ipMode, priority: priority, interval: interval, logErrors: logErrors.checked, logDebug: logDebug.checked, logSocket: logDebugSocket.checked)
            
            // update buttons
            self.ipMode.isEnabled = false
            self.interface.isEnabled = false
            self.interval.isEnabled = false
            self.addPointButton.isEnabled = true
            self.reset.isEnabled = true
            
        }

        // update the button title
        startStopButton.title = viewModel.started ? "Stop" : "Start"

    }
    
    /**
     Resets the producer, creating a new identifier and removing all points.
     
        - Parameters:
            - sender: The button sending this action.
     
    */
    @IBAction func resetProducer(_ sender: AnyObject) {
        
        viewModel.resetProducer()
        
        // update buttons
        self.ipMode.isEnabled = true
        self.interface.isEnabled = true
        self.interval.isEnabled = true
        self.addPointButton.isEnabled = false
        self.reset.isEnabled = false
        
        // update the button title
        startStopButton.title = "Start"
        
        // reload to clear points and consumers
        pointsCollectionView.reloadData()
        consumersTableView.reloadData()

        view.window?.title = "OTP Producer {\(viewModel.identifierCid.uuidString)}"
        
    }
    
    /**
     Changes whether to log for the selected check button.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func changeLogging(_ sender: NSButton) {
        
        switch sender {
        case logErrors:
            viewModel.logErrors(sender.checked)
        case logDebug:
            viewModel.logDebug(sender.checked)
        case logDebugSocket:
            viewModel.logDebugSocket(sender.checked)
        default:
            break
        }
        
    }
    
    /**
     Changes the interface name based on the selected interface item.
     
     - Parameters:
        - sender: The popup button sending this action.
     
    */
    @IBAction func changeInterface(_ sender: NSPopUpButton) {
        
        // get the name for the selected interface
        guard let object = sender.selectedItem?.representedObject as? Dictionary<String, String>, let shortTitle = object[ShortTitleCell.shortTitle] else { return }

        // update the interface name as selected
        viewModel.interfaceName = shortTitle
        
    }
    
}

// MARK: -
// MARK: -

/**
 Producer Model Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ProducerController: ProducerModelDelegate {
    
    /**
     Called to notify the delegate that new or changed consumers were discovered.
     
     - Parameters:
        - index: The index of this consumer in the array of consumer, where it has already been added to the table view.
     
    */
    func changedConsumer(atIndex index: Int? = nil) {

        DispatchQueue.main.async {

            if let index = index {
                
                let indexes = (0..<self.consumersTableView.tableColumns.count)

                // reload the table for this consumer
                self.consumersTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(indexes))
                
            } else {
                
                // reload the whole table
                self.consumersTableView.reloadData()
                
            }
            
        }
        
    }
    
    /**
     Called to notify the delegate that a point has been changed.
     
     - Parameters:
        - index: An optional index of the point.

    */
    func changedPoint(atIndex index: Int?) {
        
        DispatchQueue.main.async {
        
            // reload the points collection view
            if let index = index {
                self.pointsCollectionView.reloadItems(at: Set([IndexPath(item: index, section: 0)]))
            } else {
                self.pointsCollectionView.reloadData()
            }
            
        }
        
    }
    
}

// MARK: -
// MARK: -

/**
 Producer Controller Extension
 
 Extensions to `ProducerController` to handle table view data source and delegate.

*/

extension ProducerController: NSTableViewDataSource, NSTableViewDelegate {
    
    /**
     The column identifiers used for this table view.
    */
    private enum ColumnIdentifiers: String {
        case name = "name"
        case cid = "cid"
        case ipAddress = "ipAddress"
        case state = "state"
        case sequenceErrors = "sequenceErrors"
        case moduleIdentifiers = "moduleIdentifiers"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.consumers.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        // there must be a column identifier
        guard let identifier = tableColumn?.identifier, let column = ColumnIdentifiers(rawValue: identifier.rawValue) else { return nil }
        
        // get the consumer
        let consumer = viewModel.consumers[row]
            
        // create a text cell view
        let textCellView: NSTableCellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView

        switch column {
        case .name:
            textCellView.textField?.stringValue = consumer.name
        case .cid:
            textCellView.textField?.stringValue = consumer.cid.uuidString
        case .ipAddress:
            textCellView.textField?.stringValue = consumer.ipAddress
        case .state:
            textCellView.textField?.stringValue = consumer.state.rawValue.capitalized
        case .sequenceErrors:
            textCellView.textField?.stringValue = "\(consumer.sequenceErrors)"
        case .moduleIdentifiers:
            textCellView.textField?.stringValue = consumer.supportedModuleIdentifiers.map { $0 }.joined(separator: ", ")
        }
        
        // the text field should not be editable
        textCellView.textField?.isEditable = false

        return textCellView
        
    }
    
}


// MARK: -
// MARK: -

/**
 Producer Controller Extension
 
 Extensions to `ProducerController` to handle collection view data source.

*/

extension ProducerController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.points.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        // there must be a valid point item at this index
        guard let item = collectionView.makeItem(withIdentifier: ProducerPointItem.identifier, for: indexPath) as? ProducerPointItem else { return NSCollectionViewItem() }

        // get the point
        let point = viewModel.points[indexPath.item]
        
        // does the point have a fade pattern?
        let pattern = viewModel.fadingPoints.first(where: { $0.address == point.address && $0.priority == point.priority })?.pattern
        
        // update any fade elements
        item.refreshPattern(activePattern: pattern)
        
        let fading = pattern == nil ? false : true

        // update any point modules
        item.refreshPosition(point.modules.first(where: { $0.moduleIdentifier == OTPModulePosition.identifier }) as? OTPModulePosition, fading: fading)
        item.refreshPositionVelAccel(point.modules.first(where: { $0.moduleIdentifier == OTPModulePositionVelAccel.identifier }) as? OTPModulePositionVelAccel, fading: fading)
        item.refreshRotation(point.modules.first(where: { $0.moduleIdentifier == OTPModuleRotation.identifier }) as? OTPModuleRotation, fading: fading)
        item.refreshRotationVelAccel(point.modules.first(where: { $0.moduleIdentifier == OTPModuleRotationVelAccel.identifier }) as? OTPModuleRotationVelAccel, fading: fading)
        item.refreshScale(point.modules.first(where: { $0.moduleIdentifier == OTPModuleScale.identifier }) as? OTPModuleScale)
        item.refreshReferenceFrame(point.modules.first(where: { $0.moduleIdentifier == OTPModuleReferenceFrame.identifier }) as? OTPModuleReferenceFrame)
        
        // update the point properties
        item.address.stringValue = point.address.description
        item.priority.stringValue = "\(point.priority)"
        item.name.stringValue = point.name
        
        item.index = indexPath.item
        item.delegate = self

        return item
        
    }
    
}

// MARK: -
// MARK: -

/**
 Producer Controller Extension
 
 Extensions to `ProducerController` to handle text field delegate notifications.

*/

extension ProducerController: NSTextFieldDelegate {
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        
        let string = fieldEditor.string

        switch control {
        case name:
            viewModel.updateProducerName(string)
        default:
            break
        }
        
        return true
        
    }
    
}

// MARK: -
// MARK: -

/**
 Producer Controller Extension
 
 Extensions to `ProducerController` to handle window delegate notifications.

*/

extension ProducerController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        
        if viewModel.started {
        
            // attempt to stop the producer
            viewModel.stopProducer()
            
        }

        // notify the delegate that this producer controller is closing
        viewModel.controllerDelegate?.closingProducerController(self)
        
    }
    
}

// MARK: -
// MARK: -

/**
 Add Point Controller Delegate
 
 Required methods for objects implementing this delegate.
 
*/

extension ProducerController: AddPointControllerDelegate {
    
    /**
     Called whenever a new point is created.
     
     - Parameters:
        - point: The newly created point.
     
    */
    func addPoint(_ point: OTPPoint) {

        // try to add the point
        guard viewModel.addPoint(point) else { return }
        
        pointsCollectionView.reloadData()
        
    }
    
}

// MARK: -
// MARK: -

/**
 Point Item Delegate
 
 Required methods for objects implementing this delegate.
 
*/

extension ProducerController: ProducerPointItemDelegate {
    
    /**
     Called to request that the delegate removes an existing point.
     
     - Parameters:
        - pointIndex: The index of the point.
     
    */
    func removePoint(_ pointIndex: Int) {
        
        let point = viewModel.points[pointIndex]
        
        // remove the point
        viewModel.removePoint(point)
        
        // reload all items
        pointsCollectionView.reloadData()
        
    }
    
    /**
     Called to request that the delegate to add a new module.
     
     - Parameters:
        - moduleType: The module type to be added.
        - pointIndex: The index of the point.
     
    */
    func addModule(_ moduleType: OTPModule.Type, toPointAtIndex pointIndex: Int) {

        let point = viewModel.points[pointIndex]
        
        // add the module to the point
        viewModel.addModule(moduleType, toPoint: point)
        
        // reload all items so any points with the same address show the new name
        pointsCollectionView.reloadData()

    }
    
    /**
     Called to request that the delegate removes an existing module.
     
     - Parameters:
        - moduleType: The module type to be removed.
        - pointIndex: The index of the point.
     
    */
    func removeModule(_ moduleType: OTPModule.Type, fromPointAtIndex pointIndex: Int) {
        
        let point = viewModel.points[pointIndex]
        
        // remove the module from the point
        viewModel.removeModule(moduleType, fromPoint: point)
        
        pointsCollectionView.reloadItems(at: Set([IndexPath(item: pointIndex, section: 0)]))
        
    }
    
    /**
     Called to request that the delegate updates the name of this point.
     
     - Parameters:
        - name: The new name of this point.
        - pointIndex: The index of the point.
     
    */
    func updateName(_ name: String, forPointAtIndex pointIndex: Int) {
        
        let point = viewModel.points[pointIndex]
        
        // rename all points with this address
        viewModel.renamePoints(with: point.address, name: name)
        
        // reload all items so any points with the same address show the new name
        pointsCollectionView.reloadData()
        
    }
    
    /**
     Called to request the delegate updates this module for this point.
     
     - Parameters:
        - module: The module to be updated for this point.
        - pointIndex: The index of the point.
     
    */
    func updateModule(_ module: OTPModule, forPointAtIndex pointIndex: Int) {
        
        let point = viewModel.points[pointIndex]
        
        // update this module
        viewModel.updateModule(module, forPoint: point)
        
    }
    
    /**
     Called to request the delegate starts or stops a fade for this point.
     
     - Parameters:
        - pattern: The pattern to be used for the fade.
        - pointIndex: The index of the point.

    */
    func startStopFade(withPattern pattern: Fade.Pattern, forPointAtIndex pointIndex: Int) {
        
        let point = viewModel.points[pointIndex]
        
        // start or stop the fade
        viewModel.startStopFade(withPattern: pattern, forPoint: point)
        
        pointsCollectionView.reloadItems(at: Set([IndexPath(item: pointIndex, section: 0)]))
        
    }
    
}

// MARK: -
// MARK: -

/**
 Log Delegate
 
 Required methods for objects implementing this delegate.
 
*/

extension ProducerController: LogDelegate {

    /**
     Called whenever logs are changed.
     
     - Parameters:
        - message: The log message.
     
    */
    func newLogMessage(_ message: String) {

        DispatchQueue.main.async {
        
            // ensure we have text storage
            guard let textStorage = self.logging.textStorage else { return }

            // begin editing
            textStorage.beginEditing()
            
            // append the message passed with the log attributes
            textStorage.append(NSAttributedString(string: message, attributes: Log.attributes))

            // if the length is greater than the maximum allowed remove the excess
            if textStorage.length > Log.maxSize {
                textStorage.deleteCharacters(in: NSMakeRange(0, message.count))
            }
            
            // end editing
            textStorage.endEditing()
            
            // scroll so the new line is in view
            self.logging.scrollToEndOfDocument(nil)
            
        }

    }
    
    /**
     Called whenever logs are cleared.
    */
    func clearLogs() {

        DispatchQueue.main.async {
        
            // ensure we have text storage
            guard let textStorage = self.logging.textStorage else { return }
            
            // begin editing
            textStorage.beginEditing()
            
            // remove all characters
            textStorage.deleteCharacters(in: NSMakeRange(0, textStorage.length))
            
            // end editing to apply changes
            textStorage.endEditing()
            
        }
        
    }
    
}
