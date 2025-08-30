//
//  ContentView.swift
//  AccordionTree
//
//  Created by Yuki Sasaki on 2025/08/29.
//

import SwiftUI
import CoreData

import SwiftUI
import UIKit

struct ContentView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext

    func makeUIViewController(context: Context) -> UINavigationController {
        let accordionVC = AccordionViewController(context: viewContext)
        let nav = UINavigationController(rootViewController: accordionVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}



import UIKit
import CoreData

class AccordionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {

    var context: NSManagedObjectContext
    let tableView = UITableView()
    
    var flatData: [MenuItemEntity] = []

    // FRC
    var fetchedResultsController: NSFetchedResultsController<MenuItemEntity>!

    // 検索文字列
    var topSearchText: String = ""
    var bottomSearchText: String = ""

    // MARK: - Init
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "無限アコーディオン"

        setupTableView()
        setupFRC()
        performFetchAndReload()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRootFolder)
        )
    }

    // MARK: - TableView + Search
    func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AccordionCell.self, forCellReuseIdentifier: "Cell")
        
        // 上の検索フィールド
        let topSearchField = UITextField(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        topSearchField.placeholder = "上の検索"
        topSearchField.borderStyle = .roundedRect
        topSearchField.addTarget(self, action: #selector(topSearchChanged(_:)), for: .editingChanged)
        
        // 下の検索フィールド
        let bottomSearchField = UITextField(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        bottomSearchField.placeholder = "下の検索"
        bottomSearchField.borderStyle = .roundedRect
        bottomSearchField.addTarget(self, action: #selector(bottomSearchChanged(_:)), for: .editingChanged)
        
        tableView.tableHeaderView = topSearchField
        tableView.tableFooterView = bottomSearchField
        
        view.addSubview(tableView)
    }

    // MARK: - FRC
    func setupFRC() {
        let request: NSFetchRequest<MenuItemEntity> = MenuItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        request.predicate = NSPredicate(format: "parent == nil")
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
    }

    func performFetchAndReload() {
        do {
            try fetchedResultsController.performFetch()
            if let roots = fetchedResultsController.fetchedObjects {
                flatData = flatten(roots)
                tableView.reloadData()
            }
        } catch {
            print("FRC fetch error: \(error)")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let roots = controller.fetchedObjects as? [MenuItemEntity] {
            flatData = flatten(roots)
            tableView.reloadData()
        }
    }

    // MARK: - Flatten
    func flatten(_ items: [MenuItemEntity]) -> [MenuItemEntity] {
        var result: [MenuItemEntity] = []
        for item in items {
            result.append(item)
            if item.isExpanded,
               let children = item.children?.allObjects as? [MenuItemEntity] {
                result.append(contentsOf: flatten(children))
            }
        }
        return result
    }

    // MARK: - 検索
    @objc func topSearchChanged(_ sender: UITextField) {
        topSearchText = sender.text ?? ""
        updateFetchPredicate()
    }

    @objc func bottomSearchChanged(_ sender: UITextField) {
        bottomSearchText = sender.text ?? ""
        updateFetchPredicate()
    }

    func updateFetchPredicate() {
        var predicates: [NSPredicate] = [NSPredicate(format: "parent == nil")]
        if !topSearchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", topSearchText))
        }
        if !bottomSearchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", bottomSearchText))
        }
        fetchedResultsController.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        performFetchAndReload()
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flatData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let item = flatData[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! AccordionCell
        cell.textLabel?.text = item.title
        cell.indentationLevel = level(for: item)
        cell.arrowImageView.isHidden = (item.children?.count ?? 0) == 0
        cell.arrowImageView.transform = item.isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity

        cell.onArrowTapped = { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            item.isExpanded.toggle()
            try? self.context.save()
            self.flatData = self.flatten(self.fetchedResultsController.fetchedObjects ?? [])
            UIView.animate(withDuration: 0.25) {
                cell.arrowImageView.transform = item.isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity
            }
            self.tableView.reloadData()
        }

        return cell
    }

    // MARK: - Context Menu
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let item = flatData[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let addFolder = UIAction(title: "フォルダ追加", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
                self?.addChildFolder(to: item)
            }
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.delete(item: item)
            }
            return UIMenu(title: "", children: [addFolder, delete])
        }
    }

    // MARK: - Hierarchy Helpers
    func level(for item: MenuItemEntity) -> Int {
        var level = 0
        var current = item.parent
        while current != nil {
            level += 1
            current = current?.parent
        }
        return level
    }

    func addChildFolder(to parent: MenuItemEntity) {
        let newEntity = MenuItemEntity(context: context)
        newEntity.title = "新しいフォルダ"
        newEntity.isExpanded = false
        parent.addToChildren(newEntity)
        newEntity.parent = parent
        parent.isExpanded = true

        do {
            try context.save()
            flatData = flatten(fetchedResultsController.fetchedObjects ?? [])
            tableView.reloadData()
            if let index = flatData.firstIndex(of: newEntity) {
                tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            }
        } catch {
            print("保存失敗: \(error)")
        }
    }

    func delete(item: MenuItemEntity) {
        context.delete(item)
        do {
            try context.save()
        } catch {
            print("削除失敗: \(error)")
        }
    }

    @objc func addRootFolder() {
        let newFolder = MenuItemEntity(context: context)
        newFolder.title = "新しいフォルダ"
        newFolder.isExpanded = false
        newFolder.parent = nil
        do {
            try context.save()
        } catch {
            print("保存失敗: \(error)")
        }
    }
}

class MenuItem {
    let title: String
    var children: [MenuItem] = []
    var isExpanded: Bool = false
    weak var entity: MenuItemEntity?  // 追加
    
    init(title: String, children: [MenuItem] = [], entity: MenuItemEntity? = nil) {
        self.title = title
        self.children = children
        self.entity = entity
    }
}

class AccordionCell: UITableViewCell {
    let arrowImageView = UIImageView()
    var onArrowTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupArrow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupArrow() {
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = .gray
        contentView.addSubview(arrowImageView)

        NSLayoutConstraint.activate([
            arrowImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])

        arrowImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(arrowTapped))
        arrowImageView.addGestureRecognizer(tap)
    }

    @objc private func arrowTapped(_ sender: UITapGestureRecognizer) {
        onArrowTapped?()
    }
}
