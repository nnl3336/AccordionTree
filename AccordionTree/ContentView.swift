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

    var context: NSManagedObjectContext

    let tableView = UITableView()
    
    // 階層データ（ルート）
    var data: [MenuItemEntity] = []
    
    // 表示用フラットデータ
    var flatData: [MenuItemEntity] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "無限アコーディオン"

        setupTableView()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRootFolder)
        )

        // Core Data からロード
        let loadedData = loadRoots()
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
    
    // セルのコンテキストメニューから呼ばれる子追加
    func addChildFolder(to parent: MenuItemEntity) {
        let newEntity = MenuItemEntity(context: context)
        newEntity.title = "新しいフォルダ"
        newEntity.isExpanded = false

        // 親子関係
        parent.addToChildren(newEntity)
        newEntity.parent = parent

        // 追加したら親を展開状態にする
        parent.isExpanded = true

        do {
            try context.save()
            // 再ロード/再構築して表示を更新
            data = loadRoots()
            flatData = flatten(data)
            tableView.reloadData()

            // 追加した子の行までスクロールしたい場合
            if let index = flatData.firstIndex(of: newEntity) {
                tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            }

        } catch {
            print("保存失敗: \(error)")
        }
    }

    // コンテキストメニューで削除したいとき用
    func delete(item: MenuItemEntity) {
        // Core Data から削除（子も cascade 設定なら一緒に消えます）
        context.delete(item)
        do {
            try context.save()
            data = loadRoots()
            flatData = flatten(data)
            tableView.reloadData()
        } catch {
            print("削除失敗: \(error)")
        }
    }

    
    // MARK: - UITableViewDelegate (Context Menu)
    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        
        let item = flatData[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            // フォルダ追加
            let addFolder = UIAction(
                title: "子フォルダを追加",
                image: UIImage(systemName: "folder.badge.plus")
            ) { [weak self] _ in
                self?.addChildFolder(to: item)
            }

            // 削除
            let delete = UIAction(
                title: "削除",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.delete(item: item)
            }

            return UIMenu(title: "", children: [addFolder, delete])
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

    // MARK: - Core Data
    func loadRoots() -> [MenuItemEntity] {
        let request: NSFetchRequest<MenuItemEntity> = MenuItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil")
        do {
            return try context.fetch(request)
        } catch {
            print("fetch error: \(error)")
            return []
        }
    }

    // Core Data でサンプルデータを作成
    func setupSampleData() -> [MenuItemEntity] {
        let fruit = MenuItemEntity(context: context)
        fruit.title = "Fruit"
        fruit.isExpanded = false

        let apple = MenuItemEntity(context: context)
        apple.title = "Apple"
        apple.parent = fruit
        fruit.addToChildren(apple)

        let banana = MenuItemEntity(context: context)
        banana.title = "Banana"
        banana.parent = fruit
        fruit.addToChildren(banana)

        let vegetables = MenuItemEntity(context: context)
        vegetables.title = "Vegetables"
        vegetables.isExpanded = false

        let carrot = MenuItemEntity(context: context)
        carrot.title = "Carrot"
        carrot.parent = vegetables
        vegetables.addToChildren(carrot)

        do {
            try context.save()
        } catch {
            print("保存失敗: \(error)")
        }

        return [fruit, vegetables]
    }

    @objc func addRootFolder() {
        let newFolder = MenuItemEntity(context: context)
        newFolder.title = "新しいフォルダ"
        newFolder.isExpanded = false
        newFolder.parent = nil

        do {
            try context.save()
            data = loadRoots()
            flatData = flatten(data)
            tableView.reloadData()
        } catch {
            print("保存に失敗: \(error)")
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flatData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = flatData[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! AccordionCell
        cell.textLabel?.text = item.title
        cell.indentationLevel = level(for: item)
        cell.setExpanded(item.isExpanded)

        // 矢印だけタップ
        let tap = UITapGestureRecognizer(target: self, action: #selector(arrowTapped(_:)))
        cell.arrowImageView.addGestureRecognizer(tap)
        cell.arrowImageView.tag = indexPath.row
        return cell
    }

    @objc func arrowTapped(_ sender: UITapGestureRecognizer) {
        guard let row = sender.view?.tag else { return }
        let item = flatData[row]
        item.isExpanded.toggle()
        flatData = flatten(data)
        tableView.reloadData()
    }


    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = flatData[indexPath.row]
        item.isExpanded.toggle()
        do { try context.save() } catch { print(error) }
        flatData = flatten(data)
        tableView.reloadData()
    }

    // MARK: - 階層レベル計算
    func level(for item: MenuItemEntity) -> Int {
        var level = 0
        var current = item.parent
        while current != nil {
            level += 1
            current = current?.parent
        }
        return level
    }

    func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AccordionCell.self, forCellReuseIdentifier: "Cell") // ←ここ
        view.addSubview(tableView)
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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupArrow()
    }
    
    required init?(coder: NSCoder) { fatalError() }

    private func setupArrow() {
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arrowImageView)
        NSLayoutConstraint.activate([
            arrowImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        arrowImageView.isUserInteractionEnabled = true
    }

    func setExpanded(_ expanded: Bool) {
        arrowImageView.image = UIImage(systemName: expanded ? "chevron.down" : "chevron.right")
    }
}
