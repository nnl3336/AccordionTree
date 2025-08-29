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

class AccordionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var context: NSManagedObjectContext  // ← ここ追加

    let tableView = UITableView()
    
    // 元の階層データ
    var data: [MenuItem] = []
    
    // 表示用のフラットデータ
    var flatData: [MenuItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "無限アコーディオン"

        setupTableView()

        // NavigationBar に「＋」ボタン
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRootFolder)
        )

        // Core Data の context がある場合はそこから読み込む
        // Core Data の context がある場合はそこから読み込む
        let loadedData = loadMenuFromCoreData(context: context)
        data = loadedData.isEmpty ? setupSampleData() : loadedData
        flatData = flatten(data)
        tableView.reloadData()

    }
    
    init(context: NSManagedObjectContext) {
            self.context = context
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    
    
    
    
   

    
    func findEntity(for item: MenuItem, in items: [MenuItem]) -> MenuItemEntity? {
        for parent in items {
            if parent === item {
                return parent.entity  // MenuItem に `var entity: MenuItemEntity?` を保持させておく
            }
            if let found = findEntity(for: item, in: parent.children) {
                return found
            }
        }
        return nil
    }

    
    func addChildFolder(to parentItem: MenuItem) {
        let newEntity = MenuItemEntity(context: context)
        newEntity.title = "新しいフォルダ"
        newEntity.isExpanded = false

        // 親を設定
        newEntity.parent = parentItem.entity

        do {
            try context.save()
            
            // 新しい MenuItem を親の children に追加
            let newItem = MenuItem(title: newEntity.title ?? "", entity: newEntity)
            parentItem.children.append(newItem)
            parentItem.isExpanded = true // 展開状態にする
            
            flatData = flatten(data)
            tableView.reloadData()
        } catch {
            print("保存に失敗: \(error)")
        }
    }




    
    // UITableViewDelegate に追加
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        
        let item = flatData[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let addFolder = UIAction(title: "フォルダを追加", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
                self?.addChildFolder(to: item)
            }
            return UIMenu(title: "", children: [addFolder])
        }
    }


    // sample data を返すメソッドに変更
    func setupSampleData() -> [MenuItem] {
        let item1 = MenuItem(title: "Fruit", children: [
            MenuItem(title: "Apple"),
            MenuItem(title: "Banana"),
            MenuItem(title: "Citrus", children: [
                MenuItem(title: "Orange"),
                MenuItem(title: "Lemon")
            ])
        ])
        let item2 = MenuItem(title: "Vegetables", children: [
            MenuItem(title: "Carrot"),
            MenuItem(title: "Lettuce")
        ])
        return [item1, item2]
    }

    @objc func addRootFolder() {
        //guard let context = context else { return }
        
        let newFolder = MenuItemEntity(context: context)
        newFolder.title = "新しいフォルダ"
        newFolder.isExpanded = false
        newFolder.parent = nil // 第一階層
        
        do {
            try context.save()
            data = loadMenuFromCoreData(context: context)
            flatData = flatten(data)
            tableView.reloadData()
        } catch {
            print("保存に失敗: \(error)")
        }
    }

    
    func loadMenuFromCoreData(context: NSManagedObjectContext) -> [MenuItem] {
        let request: NSFetchRequest<MenuItemEntity> = MenuItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil") // ← ルートのみ取得
        do {
            let roots = try context.fetch(request)
            return roots.map { convert(entity: $0) }
        } catch {
            print(error)
            return []
        }
    }

    func convert(entity: MenuItemEntity) -> MenuItem {
        let children = entity.children?.allObjects as? [MenuItemEntity] ?? []
        let menuItem = MenuItem(
            title: entity.title ?? "",
            children: children.map { convert(entity: $0) },
            entity: entity  // ← ここで紐付け
        )
        menuItem.isExpanded = entity.isExpanded
        return menuItem
    }


    
    func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
    }
    
    func setupData() {
        // サンプルの無限階層データ
        let item1 = MenuItem(title: "Fruit", children: [
            MenuItem(title: "Apple"),
            MenuItem(title: "Banana"),
            MenuItem(title: "Citrus", children: [
                MenuItem(title: "Orange"),
                MenuItem(title: "Lemon")
            ])
        ])
        
        let item2 = MenuItem(title: "Vegetables", children: [
            MenuItem(title: "Carrot"),
            MenuItem(title: "Lettuce")
        ])
        
        data = [item1, item2]
    }
    
    // MARK: - Flatten
    func flatten(_ items: [MenuItem]) -> [MenuItem] {
        var result: [MenuItem] = []
        for item in items {
            result.append(item)
            if item.isExpanded {
                result.append(contentsOf: flatten(item.children))
            }
        }
        return result
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flatData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = flatData[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = item.title
        cell.indentationLevel = levelForItem(item)
        cell.accessoryType = item.children.isEmpty ? .none : .disclosureIndicator
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = flatData[indexPath.row]
        guard !item.children.isEmpty else { return }
        
        item.isExpanded.toggle()
        flatData = flatten(data)
        tableView.reloadData()

    }
    
    // MARK: - 階層レベル計算
    func levelForItem(_ item: MenuItem, currentLevel: Int = 0, in items: [MenuItem]? = nil) -> Int {
        let itemsToSearch = items ?? data
        for parent in itemsToSearch {
            if parent === item {
                return currentLevel
            } else if !parent.children.isEmpty {
                let foundLevel = levelForItem(item, currentLevel: currentLevel + 1, in: parent.children)
                if foundLevel != -1 {
                    return foundLevel
                }
            }
        }
        return -1
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
