import UIKit

// MARK: - Models

enum AppStoreSection: Int, Hashable, CaseIterable {
    case featured
    case topCharts
    case categories
}

enum AppStoreItem: Hashable {
    case featured(FeaturedItem)
    case topChart(TopChartItem)
    case category(CategoryItem)
}

struct FeaturedItem: Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let color: UIColor
}

struct TopChartItem: Hashable {
    let id: UUID
    let name: String
    let color: UIColor
}

struct CategoryItem: Hashable {
    let id: UUID
    let name: String
    let icon: String
}

// MARK: - Section Header

final class SectionHeaderView: UICollectionReusableView {
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
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
    }
}

// MARK: - Cells

final class FeaturedCell: UICollectionViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [subtitleLabel, titleLabel, UIView()])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: FeaturedItem) {
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle.uppercased()
        contentView.backgroundColor = item.color
    }
}

final class TopChartCell: UICollectionViewCell {
    private let iconView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [iconView, nameLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            iconView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: TopChartItem) {
        nameLabel.text = item.name
        iconView.backgroundColor = item.color
    }
}

final class CategoryCell: UICollectionViewCell {
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28)
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let separator: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [iconLabel, nameLabel, UIView()])
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        contentView.addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 58),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: CategoryItem) {
        iconLabel.text = item.icon
        nameLabel.text = item.name
    }
}

// MARK: - View Controller

final class AppStoreTodayViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<AppStoreSection, AppStoreItem>!

    // Modern cell registrations
    private let featuredRegistration = UICollectionView.CellRegistration<FeaturedCell, FeaturedItem> { cell, _, item in
        cell.configure(with: item)
    }

    private let topChartRegistration = UICollectionView.CellRegistration<TopChartCell, TopChartItem> { cell, _, item in
        cell.configure(with: item)
    }

    private let categoryRegistration = UICollectionView.CellRegistration<CategoryCell, CategoryItem> { cell, _, item in
        cell.configure(with: item)
    }

    private let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
        elementKind: UICollectionView.elementKindSectionHeader
    ) { supplementaryView, _, indexPath in
        let title: String
        switch AppStoreSection(rawValue: indexPath.section) {
        case .featured:   title = "Featured"
        case .topCharts:  title = "Top Charts"
        case .categories: title = "Categories"
        case .none:       title = ""
        }
        supplementaryView.configure(title: title)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Today"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        configureCollectionView()
        configureDataSource()
        applyInitialSnapshot()
    }

    // MARK: - Layout

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = AppStoreSection(rawValue: sectionIndex) else { return nil }
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

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.92),
                                               heightDimension: .absolute(350))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }

    private static func topChartsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let containerWidth = environment.container.effectiveContentSize.width
        let itemWidth = (containerWidth - 16 * 2 - 12 * 2) / 3
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth),
                                               heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [sectionHeader()]
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }

    private static func sectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                          heightDimension: .absolute(44))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    // MARK: - Collection View & Data Source

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            [weak self] collectionView, indexPath, item in
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
        var snapshot = NSDiffableDataSourceSnapshot<AppStoreSection, AppStoreItem>()
        snapshot.appendSections(AppStoreSection.allCases)

        let featuredItems: [AppStoreItem] = [
            .featured(.init(id: UUID(), title: "Reimagine Your\nWorkflow", subtitle: "App of the Day", color: .systemIndigo)),
            .featured(.init(id: UUID(), title: "Get Creative\nWith Photos", subtitle: "Editors' Choice", color: .systemTeal)),
            .featured(.init(id: UUID(), title: "Level Up\nYour Fitness", subtitle: "Trending", color: .systemOrange)),
            .featured(.init(id: UUID(), title: "Mindful\nMeditation", subtitle: "New Release", color: .systemPurple)),
        ]
        snapshot.appendItems(featuredItems, toSection: .featured)

        let chartItems: [AppStoreItem] = [
            ("Instagram", UIColor.systemPink),
            ("YouTube", .systemRed),
            ("WhatsApp", .systemGreen),
            ("TikTok", .label),
            ("Spotify", .systemGreen),
            ("Twitter", .systemBlue),
            ("Snapchat", .systemYellow),
            ("Netflix", .systemRed),
        ].map { .topChart(.init(id: UUID(), name: $0.0, color: $0.1)) }
        snapshot.appendItems(chartItems, toSection: .topCharts)

        let categoryItems: [AppStoreItem] = [
            ("Games", "🎮"), ("Entertainment", "🎬"), ("Education", "📚"),
            ("Photo & Video", "📸"), ("Social Networking", "💬"), ("Health & Fitness", "❤️"),
            ("Productivity", "⚡"), ("Finance", "💰"), ("Music", "🎵"),
        ].map { .category(.init(id: UUID(), name: $0.0, icon: $0.1)) }
        snapshot.appendItems(categoryItems, toSection: .categories)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

