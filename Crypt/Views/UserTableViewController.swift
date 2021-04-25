//
//  UserTableViewController.swift
//  Crypt
//
//  Created by Mark Bourke on 24/04/2021.
//

import AppKit

enum Section {
    case main
}

extension NSUserInterfaceItemIdentifier: Equatable, ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    
    public static func ==(lhs: NSUserInterfaceItemIdentifier,
                          rhs: NSUserInterfaceItemIdentifier) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public init(stringLiteral value: Self.StringLiteralType) {
        self.init(value)
    }
}

protocol UserTableViewControllerDelegate {
    func checkboxWasClicked(enabled: Bool, index: Int)
    func tableView(_ tableView: NSTableView, didSelectRows indexSet: IndexSet)
}

class UserTableViewController: NSViewController, NSTableViewDelegate {
    
    // TableView is flipped so this must be too
    private class FlippedView: NSView {
        
        override var isFlipped: Bool {
            true
        }
    }
    
    typealias DataSource = NSTableViewDiffableDataSource<Section, User>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, User>
    
    private enum Columns: NSUserInterfaceItemIdentifier {
        case checkbox = "checkbox"
        case name = "name"
    }
    
    let tableView = NSTableView()
    var delegate: UserTableViewControllerDelegate? // don't use this with anything other than a struct otherwise there will be a retain cycle
    var items = Set<User>()
    
    private let checkboxes: Bool
    
    override func loadView() {
        view = FlippedView()
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return !checkboxes
    }
    
    @objc func selectionDidChange(_ notification: Notification) {
        delegate?.tableView(tableView, didSelectRows: tableView.selectedRowIndexes)
    }
    
    @objc func checkboxClicked(_ button: NSButton) {
        delegate?.checkboxWasClicked(enabled: button.state == .on, index: tableView.row(for: button))
    }
    
    init(checkboxes: Bool) {
        self.checkboxes = checkboxes
        super.init(nibName: nil, bundle: nil)
        
        let dataSource = DataSource(tableView: tableView) { (tableView, column, row, user) -> NSView in
            let cell = NSTableCellView()
            
            switch column.identifier {
            case Columns.checkbox.rawValue:
                let button = NSButton()
                button.title = ""
                button.setButtonType(.switch)
                button.state = .on
                button.target = self
                button.action = #selector(self.checkboxClicked(_:))
                
                button.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(button)
                
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                button.centerXAnchor.constraint(equalTo: cell.centerXAnchor).isActive = true
            case Columns.name.rawValue:
                let text = NSTextField()
                text.isBordered = false
                text.isEditable = false
                text.drawsBackground = false
                text.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(text)
                
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor).isActive = true
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor).isActive = true
                cell.textField = text
                text.stringValue = user.name
                
            default:
                fatalError("Unidentified section in data source") // this should never happen
            }
            
            return cell
        }
        
        tableView.usesAlternatingRowBackgroundColors = true
        if checkboxes {
            let column = NSTableColumn(identifier: Columns.checkbox.rawValue)
            column.title = "Allow"
            column.width = 40
            tableView.addTableColumn(column)
        }
        let column = NSTableColumn(identifier: Columns.name.rawValue)
        column.title = "Name"
        tableView.addTableColumn(column)
        
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = false
        
        tableView.dataSource = dataSource
        tableView.delegate = self
        
        view.addSubview(tableView)
        let headerView = tableView.headerView!
        view.addSubview(headerView)
        tableView.frame.origin.y += headerView.frame.height
        
        NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChange(_:)), name: NSTableView.selectionDidChangeNotification, object: tableView)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSTableView.selectionDidChangeNotification, object: tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reloadItems() {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(Array(items))
        let dataSource = tableView.dataSource as! DataSource
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        tableView.frame.size = view.bounds.size
    }
}
