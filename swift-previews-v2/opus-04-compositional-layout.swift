import UIKit

// MARK: - Data Models

enum Section: Int, CaseIterable, Hashable {
    case featured
    case topCharts
    case categories
}

enum Item: Hashable {
    case featured(FeaturedItem)
    case topChart(TopChartItem)
    case category(CategoryItem)
}

struct FeaturedItem: Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let color: UIColor

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

struct TopChartItem: Hashable {
    let id: UUID
    let name: String
    let color: UIColor

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

struct CategoryItem: Hashable {
    let id: UUID
    let name: String
    let symbolName: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Section Header

final class SectionHeaderView: UICollectionReusableView {
    static let elementKind = "section-header"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        return label
    }()

    private let seeAllButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "See All"
        config.baseForegroundColor = .systemBlue
        let button = UIButton(configuration: config)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [titleLabel, seeAllButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
    }
}

// MARK: - View Controller

final class TodayViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    // Cell registrations
    private let featuredRegistration = UICollectionView.CellRegistration<UICollectionViewCell, FeaturedItem> { cell, _, item in
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = item.color
        cell.contentView.layer.cornerRadius = 16
        cell.contentView.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        let subtitleLabel = UILabel()
        subtitleLabel.text = item.subtitle
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)

        let stack = UIStackView(arrangedSubviews: [subtitleLabel, titleLabel, UIView()])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -20),
        ])
    }

    private let topChartRegistration = UICollectionView.CellRegistration<UICollectionViewCell, TopChartItem> { cell, _, item in
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = item.color
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true

        let label = UILabel()
        label.text = item.name
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
        ])
    }

    private let categoryRegistration = UICollectionView.CellRegistration<UICollectionViewCell, CategoryItem> { cell, _, item in
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.cornerRadius = 12
        cell.backgroundConfiguration = bg

        let imageView = UIImageView(image: UIImage(systemName: item.symbolName))
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let label = UILabel()
        label.text = item.name
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [imageView, label, chevron])
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        ])
    }

    private let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
        elementKind: SectionHeaderView.elementKind
    ) { supplementaryView, _, indexPath in
        let title: String
        switch Section(rawValue: indexPath.section) {
        case .featured:   title = "Today"
        case .topCharts:  title = "Top Charts"
        case .categories: title = "Categories"
        case .none:       title = ""
        }
        supplementaryView.configure(title: title)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = false
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshot()
    }

    // MARK: - Layout

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            switch section {
            case .featured:   return Self.featuredSection(environment: environment)
            case .topCharts:  return Self.topChartsSection(environment: environment)
            case .categories: return Self.categoriesSection(environment: environment)
            }
        }
    }

    private static func featuredSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupWidth = environment.container.effectiveContentSize.width - 40 // 20pt insets each side
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(groupWidth),
                                               heightDimension: .absolute(350))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20)
        section.boundarySupplementaryItems = [headerItem()]
        return section
    }

    private static func topChartsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let containerWidth = environment.container.effectiveContentSize.width - 40
        let itemWidth = (containerWidth - 20) / 3 // 3 visible, 10pt spacing × 2

        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth),
                                              heightDimension: .absolute(itemWidth))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth),
                                               heightDimension: .absolute(itemWidth))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20)
        section.boundarySupplementaryItems = [headerItem()]
        return section
    }

    private static func categoriesSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .absolute(80))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(80))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 40, trailing: 20)
        section.boundarySupplementaryItems = [headerItem()]
        return section
    }

    private static func headerItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                          heightDimension: .estimated(44))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: SectionHeaderView.elementKind,
            alignment: .top
        )
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            guard let self else { return nil }
            switch item {
            case .featured(let data):
                return collectionView.dequeueConfiguredReusableCell(using: self.featuredRegistration, for: indexPath, item: data)
            case .topChart(let data):
                return collectionView.dequeueConfiguredReusableCell(using: self.topChartRegistration, for: indexPath, item: data)
            case .category(let data):
                return collectionView.dequeueConfiguredReusableCell(using: self.categoryRegistration, for: indexPath, item: data)
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return nil }
            return collectionView.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
        }
    }

    // MARK: - Snapshot

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)

        let featuredItems: [Item] = [
            .featured(FeaturedItem(id: UUID(), title: "Behind the Design", subtitle: "FROM THE EDITORS", color: .systemIndigo)),
            .featured(FeaturedItem(id: UUID(), title: "Get Creative With Photos", subtitle: "SPOTLIGHT", color: .systemTeal)),
            .featured(FeaturedItem(id: UUID(), title: "Apps We Love", subtitle: "THE DAILY LIST", color: .systemOrange)),
            .featured(FeaturedItem(id: UUID(), title: "A New Way to Journal", subtitle: "FEATURED", color: .systemPink)),
        ]
        snapshot.appendItems(featuredItems, toSection: .featured)

        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemPurple, .systemYellow,
                                  .systemMint, .systemCyan, .systemBrown, .systemIndigo, .systemOrange]
        let chartNames = ["Threads", "Instagram", "WhatsApp", "TikTok", "YouTube",
                          "Spotify", "Snapchat", "Gmail", "Discord", "Telegram"]
        let topChartItems: [Item] = zip(chartNames, colors).map { name, color in
            .topChart(TopChartItem(id: UUID(), name: name, color: color))
        }
        snapshot.appendItems(topChartItems, toSection: .topCharts)

        let categories: [(String, String)] = [
            ("Games", "gamecontroller.fill"),
            ("Entertainment", "tv.fill"),
            ("Social Networking", "person.2.fill"),
            ("Photo & Video", "camera.fill"),
            ("Shopping", "bag.fill"),
            ("Health & Fitness", "heart.fill"),
            ("Productivity", "checkmark.seal.fill"),
            ("Music", "music.note"),
            ("Finance", "dollarsign.circle.fill"),
            ("Education", "book.fill"),
        ]
        let categoryItems: [Item] = categories.map { name, symbol in
            .category(CategoryItem(id: UUID(), name: name, symbolName: symbol))
        }
        snapshot.appendItems(categoryItems, toSection: .categories)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

