//
//  Navigator_macOS.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 02.03.25.
//

#if os(macOS)

import AppKit
import SwiftUI


class NavigatorVC: NSViewController {
    private var collectionView: NSCollectionView!
    private var dataSource: NSCollectionViewDiffableDataSource<Int, NavigatorItem>!
    
    private var data: [NavigatorItem] = []
    
    var itemSelected: (_ item: NavigatorItem) -> Void = { _ in }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupUI()
    }
    
    
    private func setupUI() {
        func createBasicListLayout() -> NSCollectionViewLayout {
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                 heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
          
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .absolute(44))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                             subitems: [item])
          
            let section = NSCollectionLayoutSection(group: group)


            let layout = NSCollectionViewCompositionalLayout(section: section)
            return layout
        }
        
        collectionView = .init(frame: .init(origin: .zero, size: .init(width: 10, height: 10)))
        //collectionView = .init(frame: view.bounds)
        collectionView.collectionViewLayout = createBasicListLayout()
        collectionView.delegate = self
        collectionView.autoresizingMask = [.height, .height]
        collectionView.register(NSCollectionViewItem.self, forItemWithIdentifier: .init("cell"))
        //collectionView.backgroundColor = .red
        view.addSubview(collectionView)
        
//        let parentCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, NavigatorItem> { cell, indexPath, item in
//            var content = cell.defaultContentConfiguration()
//            content.text = item.name
//            
//            cell.accessories = [.outlineDisclosure()]
//            
//            //cell.indentationLevel = item.level
//            cell.contentConfiguration = content
//        }
//        
//        let childCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, NavigatorItem> { cell, indexPath, item in
//            var content = cell.defaultContentConfiguration()
//            content.text = item.name
//            
//            //cell.indentationLevel = item.level
//            cell.contentConfiguration = content
//        }
        
        dataSource = NSCollectionViewDiffableDataSource<Int, NavigatorItem>(collectionView: collectionView) { collectionView, IndexPath, item in
            let cell = collectionView.makeItem(withIdentifier: .init("cell"), for: IndexPath)
            
            cell.title = item.name
            
            return cell
        }
        
//        dataSource = UICollectionViewDiffableDataSource<Int, NavigatorItem>(collectionView: collectionView) {
//            (collectionView, indexPath, item) -> UICollectionViewCell? in
//            return collectionView.dequeueConfiguredReusableCell(
//                using: item.items != nil ? parentCellRegistration : childCellRegistration,
//                for: indexPath,
//                item: item
//            )
//        }
        
        applySnapshot()
    }
}


extension NavigatorVC {
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, NavigatorItem>()
//
//        let section = NavigatorItem(name: "lala", value: .section)
        snapshot.appendSections([0])
        snapshot.appendItems(data, toSection: 0)
//        snapshot.appendItems([.init(name: "test", value: .mesh(0, type: .standard))], toSection: 1)
        dataSource.apply(snapshot)
        
//        //var snapshot = NSDiffableDataSourceSectionSnapshot<NavigatorItem>()
//        func append(_ items: [NavigatorItem], in parent: NavigatorItem? = nil) {
//            snapshot.appendSections(items)
//            //snapshot.appendItems(items, toSection: parent)
//            for (itemIndex, item) in items.enumerated() {
//                if let children = item.items {
//                    append(children, in: item)
//                }
//            }
//        }
//        append(data)
//
    }
}


extension NavigatorVC: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        itemSelected(item)
    }
}


extension NavigatorVC: NavigatorItemProviderDelegate {
    func navigatorItemSetItems(_ items: [NavigatorItem]) {
        data = items
        applySnapshot()
    }
}



// MARK: - New

class NavigationOutline: NSViewController {
    private var outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    
    private var data: [NavigatorItem] = []
    
    var itemSelected: (_ item: NavigatorItem) -> Void = { _ in }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupUI()
    }
    
    
    private func setupUI() {
//        collectionView = .init(frame: .zero)
//        //collectionView = .init(frame: view.bounds)
//        collectionView.delegate = self
//        collectionView.dataSource = self
//        collectionView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(collectionView)
//        NSLayoutConstraint.activate([
//            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
//            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
        
        
        outlineView.delegate = self
        outlineView.dataSource = self
        
        
        let column = NSTableColumn(identifier: .init("test_column"))
        column.title = "lala"
        column.isEditable = false
        outlineView.addTableColumn(column)
        //outlineView.verticalMotionCanBeginDrag = false
        
        //outlineView.frame = view.bounds
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .custom
        outlineView.headerView = nil
        outlineView.outlineTableColumn = column
        outlineView.allowsMultipleSelection = true
        
        scrollView.wantsLayer = true
        scrollView.documentView = outlineView
        scrollView.autoresizesSubviews = true
        scrollView.autoresizingMask = [.width, .height]
        
        //scrollView.frame = view.bounds
        scrollView.automaticallyAdjustsContentInsets = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        view.addSubview(scrollView)
    }
    
}


extension NavigationOutline {
    private func applySnapshot() {
        //scrollView.frame = view.bounds
        //outlineView.frame = view.bounds
        outlineView.reloadData()
    }
}


fileprivate class TopazTableCellView: NSTableCellView {
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }
    
    
#if os(macOS)
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayout()
    }
#endif
    
    
    public func setupLayout() {
        //
    }
}


fileprivate class SomeView: TopazTableCellView {
    let label = NSTextField(string: "Hello")
    
    override func setupLayout() {
        //label.delegate = self
        label.lineBreakMode = .byTruncatingMiddle
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.focusRingType = .none
        label.autoresizingMask = [.width]
        addSubview(label)
        
        textField = label
    }
}


extension NavigationOutline: NSOutlineViewDelegate, NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? NavigatorItem else {
            return nil
        }
        
        let identifier = NSUserInterfaceItemIdentifier("outline_item")
        let cell: SomeView = {
            //let width: CGFloat = outlineView.bounds.width
            if let bakedCell = outlineView.makeView(withIdentifier: identifier, owner: nil) as? SomeView {
                //bakedCell.label.frame.size.width = width
                //bakedCell.frame.size.width = width
                return bakedCell
            }
            
            let freshCell = SomeView(frame: .init())
            //freshCell.label.frame.size.width = width
            //freshCell.frame.size.width = width
            freshCell.autoresizingMask = [.width]
            freshCell.identifier = identifier
            return freshCell
        }()
        
        
        cell.label.stringValue = item.name
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return data.count
        }
        
        guard let item = item as? NavigatorItem else {
            return 0
        }
        
        return item.items?.count ?? 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item as? NavigatorItem else {
            return data[index]
        }
        
        guard let items = item.items else {
            return data[index]
        }
        
        return items[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        item
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? NavigatorItem {
            if let items = item.items {
                return !items.isEmpty
            }
            
            return false
        }
        
        return false
    }
    
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? NavigatorItem else {
            return
        }
        
        itemSelected(item)
    }
}


extension NavigationOutline: NavigatorItemProviderDelegate {
    func navigatorItemSetItems(_ items: [NavigatorItem]) {
        data = items
        applySnapshot()
    }
}



#if true

struct NavigatorTestView: NSViewControllerRepresentable {
    var dataProvider: NavigatorItemProvider?
    var itemSelected: (_ item: NavigatorItem) -> Void = { _ in }
    
    func makeNSViewController(context: Context) -> NavigationOutline {
        let vc = NavigationOutline()
        dataProvider?.delegate = vc
        vc.itemSelected = itemSelected
        return vc
    }
    
    func updateNSViewController(_ nsViewController: NavigationOutline, context: Context) {
        //
    }
}

#else

struct NavigatorTestView: NSViewControllerRepresentable {
    var dataProvider: NavigatorItemProvider?
    var itemSelected: (_ item: NavigatorItem) -> Void = { _ in }
    
    func makeNSViewController(context: Context) -> NavigatorVC {
        let vc = NavigatorVC()
        dataProvider?.delegate = vc
        vc.itemSelected = itemSelected
        return vc
    }
    
    func updateNSViewController(_ nsViewController: NavigatorVC, context: Context) {
        //
    }
}

#endif


#Preview {
    NavigatorVC()
}


#endif
