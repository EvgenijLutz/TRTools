//
//  Navigator_iOS.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 28.02.25.
//

#if os(iOS)

import UIKit
import SwiftUI


// https://www.swiftjectivec.com/collapsable-collectionview/


class NavigatorVC: UIViewController {
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, NavigatorItem>!
    
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
        let configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        collectionView = .init(frame: view.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        //collectionView.backgroundColor = .red
        view.addSubview(collectionView)
        
        let parentCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, NavigatorItem> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            
            cell.accessories = [.outlineDisclosure()]
            
            //cell.indentationLevel = item.level
            cell.contentConfiguration = content
        }
        
        let childCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, NavigatorItem> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            
            //cell.indentationLevel = item.level
            cell.contentConfiguration = content
        }
        
        dataSource = UICollectionViewDiffableDataSource<Int, NavigatorItem>(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(
                using: item.items != nil ? parentCellRegistration : childCellRegistration,
                for: indexPath,
                item: item
            )
        }
        
        applySnapshot()
    }
    
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSectionSnapshot<NavigatorItem>()
        func append(_ items: [NavigatorItem], in parent: NavigatorItem? = nil) {
            snapshot.append(items, to: parent)
            for item in items {
                if let children = item.items {
                    append(children, in: item)
                }
            }
        }
        append(data)
        
        dataSource.apply(snapshot, to: 0)
    }
    
}


extension NavigatorVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        itemSelected(item)
    }
}


extension NavigatorVC: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return []
        }
        
        guard item.shared else {
            return []
        }
        
        return [UIDragItem(itemProvider: .init(object: item.name as NSString))]
    }
}


extension NavigatorVC: NavigatorItemProviderDelegate {
    func navigatorItemSetItems(_ items: [NavigatorItem]) {
        data = items
        applySnapshot()
    }
}


struct NavigatorTestView: UIViewControllerRepresentable {
    var dataProvider: NavigatorItemProvider?
    var itemSelected: (_ item: NavigatorItem) -> Void = { _ in }
    
    func makeUIViewController(context: Context) -> NavigatorVC {
        let vc = NavigatorVC()
        dataProvider?.delegate = vc
        vc.itemSelected = itemSelected
        return vc
    }
    
    func updateUIViewController(_ uiViewController: NavigatorVC, context: Context) {
        //
    }
}


#Preview {
    NavigatorVC()
}


#endif
