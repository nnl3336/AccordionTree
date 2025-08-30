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

    // MARK: - 初期化
    // コンテキストを受け取ってビューコントローラを初期化
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Viewのセットアップ
    // viewDidLoadでテーブルビューとFRCをセットアップし、ナビゲーションボタンを追加
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "無限アコーディオン"
        
        setupTableView()       // テーブルビューの初期設定
        setupFRC()             // FRCの初期設定
        performFetchAndReload()// データを取得してフラット化
        setupTableView()       // 再度テーブルビュー設定（ヘッダー更新など）
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRootFolder)
        )
        
        sortFlatData(by: currentSort) // UserDefaults から復元してソート
    }
    
    // MARK: - 検索結果更新
    // 入力された検索文字列に基づき、フラット化されたデータを更新
    func updateSearchResults() {
        let roots = fetchedResultsController.fetchedObjects ?? []
        flatData = flattenWithSearch(roots, keyword: topSearchText)
        tableView.reloadData()
    }

    // MARK: - 階層を再帰的にフラット化（検索対応）
    func flattenWithSearch(_ items: [MenuItemEntity], keyword: String?) -> [MenuItemEntity] {
        var result: [MenuItemEntity] = []
        
        for item in items {
            let children = (item.children?.allObjects as? [MenuItemEntity]) ?? []
            let filteredChildren = flattenWithSearch(children, keyword: keyword)
            
            let matchSelf = keyword.map { item.title?.localizedCaseInsensitiveContains($0) ?? false } ?? true
            
            if matchSelf || !filteredChildren.isEmpty {
                if !filteredChildren.isEmpty {
                    item.isExpanded = true  // 子がマッチしたら親を展開
                }
                result.append(item)
                result.append(contentsOf: filteredChildren)
            }
        }
        
        return result
    }

    // MARK: - テーブルビューの削除ボタン設定
    func tableView(_ tableView: UITableView,
                   editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            // 並べ替えモードでは削除ボタンを出さない
            return .none
        } else {
            // 通常は削除可能
            return .delete
        }
    }

    // MARK: - スワイプで削除
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if currentSort == .order {
            // 並べ替え中は削除不可
            return nil
        }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            guard let self = self else { return }
            let item = self.flatData[indexPath.row]
            self.context.delete(item)
            try? self.context.save()
            completion(true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    // MARK: - セルの移動可否
    // セルを移動できるか
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // 現在のソートが「順番」のときだけ移動可能
        return currentSort == .order
    }

    // MARK: - セル移動時の処理
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard currentSort == .order else { return }

        // flatData を並び替え
        let movedItem = flatData.remove(at: sourceIndexPath.row)
        flatData.insert(movedItem, at: destinationIndexPath.row)

        // 並び順(order)を更新
        for (index, item) in flatData.enumerated() {
            item.order = Int64(index)
        }

        do {
            try context.save()
            print("並び替え保存成功")
        } catch {
            print("順序保存に失敗: \(error)")
        }

        // デバッグ用に現在の順序を出力
        print("=== 並び順デバッグ ===")
        for item in flatData {
            print("\(item.title ?? "無題") : order = \(item.order)")
        }
        print("====================")
    }


    // MARK: - ソートタイプ定義
    enum SortType: String, CaseIterable {
        case createdAt
        case title
        case currentDate
        case order
    }


    var currentSort: SortType {
        get {
            if let raw = UserDefaults.standard.string(forKey: "currentSort"),
               let type = SortType(rawValue: raw) {
                return type
            }
            return .createdAt // デフォルト
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "currentSort")
        }
    }
    
    // MARK: - 並べ替え処理
    func sortFlatData(by type: SortType) {
        currentSort = type // UserDefaults に自動保存
        
        switch type {
        case .createdAt:
            flatData.sort { ascending ? ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) : ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
        case .title:
            flatData.sort { ascending ? ($0.title ?? "") < ($1.title ?? "") : ($0.title ?? "") > ($1.title ?? "") }
        case .currentDate:
            flatData.sort { ascending ? ($0.currentDate ?? Date()) < ($1.currentDate ?? Date()) : ($0.currentDate ?? Date()) > ($1.currentDate ?? Date()) }
        case .order:
            flatData.sort { ascending ? $0.order < $1.order : $0.order > $1.order }
        }
        
        tableView.isEditing = (type == .order)
        tableView.reloadData()
    }

    
    // 並べ替え昇順 / 降順用
    // MARK: - 並び替え状態の永続化
        var ascending: Bool {
            get { UserDefaults.standard.bool(forKey: "ascending") }
            set { UserDefaults.standard.set(newValue, forKey: "ascending") }
        }
    
    func updateTableHeader() {
        // 並び替えボタンを作り直す
        let sortButton = UIButton(type: .system)
        sortButton.setTitle("並び替え", for: .normal)
        sortButton.menu = makeSortMenu()
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // 検索フィールドを作り直す（必要なら再利用でもOK）
        let searchField = UITextField(frame: .zero)
        searchField.placeholder = "検索"
        searchField.borderStyle = .roundedRect
        searchField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        searchField.addTarget(self, action: #selector(searchChanged(_:)), for: .editingChanged)

        // コンテナStackを組み直す
        let container = UIStackView(arrangedSubviews: [sortButton, searchField])
        container.axis = .vertical
        container.spacing = 4
        container.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 92)

        tableView.tableHeaderView = container
    }

    // メニュー生成用の関数
    func makeSortMenu() -> UIMenu {
        return UIMenu(title: "並び替え", children: [
            UIAction(
                title: "作成日",
                image: UIImage(systemName: "calendar"),
                state: currentSort == .createdAt ? .on : .off
            ) { [weak self] _ in
                self?.sortFlatData(by: .createdAt)
                self?.updateTableHeader()
            },
            UIAction(
                title: "名前",
                image: UIImage(systemName: "textformat"),
                state: currentSort == .title ? .on : .off
            ) { [weak self] _ in
                self?.sortFlatData(by: .title)
                self?.updateTableHeader()
            },
            UIAction(
                title: "追加日",
                image: UIImage(systemName: "clock"),
                state: currentSort == .currentDate ? .on : .off
            ) { [weak self] _ in
                self?.sortFlatData(by: .currentDate)
                self?.updateTableHeader()
            },
            UIAction(
                title: "順番",
                image: UIImage(systemName: "list.number"),
                state: currentSort == .order ? .on : .off
            ) { [weak self] _ in
                self?.sortFlatData(by: .order)
                self?.updateTableHeader()
            },
            // 昇順／降順の切り替えはタイトルで表現
            UIAction(
                title: ascending ? "昇順 (A→Z)" : "降順 (Z→A)",
                state: .off // ここはチェック不要（トグル扱いだから）
            ) { [weak self] _ in
                guard let self = self else { return }
                self.ascending.toggle()
                self.sortFlatData(by: self.currentSort)
                self.updateTableHeader()
            }
        ])
    }

    
    // MARK: - テーブルビュー初期設定
    // MARK: - テーブルビュー初期設定
    func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AccordionCell.self, forCellReuseIdentifier: "Cell")

        // 並び替えボタン(UIMenu付き)
        let sortButton = UIButton(type: .system)
        sortButton.setTitle("並び替え", for: .normal)
        sortButton.menu = makeSortMenu()              // メニューを追加
        sortButton.showsMenuAsPrimaryAction = true    // 長押しじゃなくタップで出るようにする

        // 検索フィールド
        let searchField = UITextField()
        searchField.placeholder = "検索"
        searchField.borderStyle = .roundedRect
        searchField.addTarget(self, action: #selector(searchChanged(_:)), for: .editingChanged)
        searchField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // ヘッダースタックにボタンと検索フィールドを縦に並べる
        let headerStack = UIStackView(arrangedSubviews: [sortButton, searchField])
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .fill
        headerStack.distribution = .fill

        let fittingSize = CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let headerHeight = headerStack.systemLayoutSizeFitting(fittingSize).height
        headerStack.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: headerHeight)
        tableView.tableHeaderView = headerStack

        view.addSubview(tableView)
    }

    // MARK: - 検索テキスト変更時
    @objc func searchChanged(_ sender: UITextField) {
        let text = sender.text ?? ""
        topSearchText = text
        updateFetchPredicate()
    }

    @objc func topSearchChanged(_ sender: UITextField) {
        guard let text = sender.text else { return }
        print("上の検索: \(text)")
        // flatDataをフィルタしてtableView.reloadData()
    }

    // MARK: - FRC（Core Data用フェッチコントローラ）設定
    func setupFRC() {
        let request: NSFetchRequest<MenuItemEntity> = MenuItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)] // ← order順に
        request.predicate = NSPredicate(format: "parent == nil")
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
    }

    // moveRowAt の実装

    // FRC が変化した時（Core Data 更新時）
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let roots = controller.fetchedObjects as? [MenuItemEntity] {
            // 展開状態を考慮して flatData を更新
            flatData = flatten(roots)
            tableView.reloadData()
        }
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

    // MARK: - 階層をフラット化（展開状態を考慮）
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

    // MARK: - 下の検索テキスト変更
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

    // MARK: - コンテキストメニュー
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

    // MARK: - 子フォルダ追加
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

    // MARK: - 削除
    func delete(item: MenuItemEntity) {
        context.delete(item)
        do {
            try context.save()
        } catch {
            print("削除失敗: \(error)")
        }
    }

    // MARK: - ルートフォルダ追加
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
