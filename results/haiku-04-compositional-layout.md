Here's a complete UIViewController implementation with a compositional layout mimicking the App Store Today tab:

```swift
import UIKit

// MARK: - View Controller

class AppStoreViewController: UIViewController {
    
    private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Today"
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        configureDataSource()
        applySnapshot()
    }
    
    private func setupCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        collectionView.collectionViewLayout = createLayout()
    }
    
    private func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment -> NSCollectionLayoutSection? in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            
            switch section {
            case .featured:
                return self.featuredSection()
            case .topCharts:
                return self.topChartsSection()
            case .categories:
                return self.categoriesSection()
            }
        }
        
        return layout
    }
    
    // MARK: - Layout Sections
    
    private func featuredSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.95),
            heightDimension: .absolute(350)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        
        // Header
        section.boundarySupplementaryItems = [createSectionHeader()]
        
        return section
    }
    
    private func topChartsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.35),
            heightDimension: .absolute(140)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 16, trailing: 4)
        
        // Header
        section.boundarySupplementaryItems = [createSectionHeader()]
        
        return section
    }
    
    private func categoriesSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(80)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        section.interGroupSpacing = 12
        
        // Header
        section.boundarySupplementaryItems = [createSectionHeader()]
        
        return section
    }
    
    private func createSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
    
    // MARK: - Data Source
    
    private func configureDataSource() {
        // Featured Cell Registration
        let featuredRegistration = UICollectionViewCellRegistration<FeaturedBannerCell, Item> { cell, _, item in
            if case .featured(let title) = item {
                cell.configure(with: title)
            }
        }
        
        // Top Charts Cell Registration
        let topChartsRegistration = UICollectionViewCellRegistration<TopChartsCell, Item> { cell, _, item in
            if case .topChart(let rank, let appName) = item {
                cell.configure(rank: rank, appName: appName)
            }
        }
        
        // Categories Cell Registration
        let categoriesRegistration = UICollectionViewCellRegistration<CategoryCell, Item> { cell, _, item in
            if case .category(let name, let description) = item {
                cell.configure(name: name, description: description)
            }
        }
        
        // Header Registration
        let headerRegistration = UICollectionViewSupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { supplementaryView, _, indexPath in
            guard let section = Section(rawValue: indexPath.section) else { return }
            supplementaryView.configure(section: section)
        }
        
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .featured:
                return collectionView.dequeueConfiguredReusableCell(
                    using: featuredRegistration,
                    for: indexPath,
                    item: item
                )
            case .topChart:
                return collectionView.dequeueConfiguredReusableCell(
                    using: topChartsRegistration,
                    for: indexPath,
                    item: item
                )
            case .category:
                return collectionView.dequeueConfiguredReusableCell(
                    using: categoriesRegistration,
                    for: indexPath,
                    item: item
                )
            }
        }
        
        dataSource?.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        
        // Featured Section
        snapshot.appendSections([.featured])
        snapshot.appendItems([
            .featured("Discover Something New"),
            .featured("Creative Apps"),
            .featured("Productivity Boost")
        ], toSection: .featured)
        
        // Top Charts Section
        snapshot.appendSections([.topCharts])
        snapshot.appendItems([
            .topChart(1, "Instagram"),
            .topChart(2, "TikTok"),
            .topChart(3, "Discord"),
            .topChart(4, "Snapchat"),
            .topChart(5, "WhatsApp")
        ], toSection: .topCharts)
        
        // Categories Section
        snapshot.appendSections([.categories])
        snapshot.appendItems([
            .category("Games", "Best games to play"),
            .category("Entertainment", "Shows and movies"),
            .category("Productivity", "Get things done"),
            .category("Health", "Wellness apps"),
            .category("Social", "Connect with others")
        ], toSection: .categories)
        
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Models

enum Section: Int, Hashable {
    case featured
    case topCharts
    case categories
    
    var title: String {
        switch self {
        case .featured:
            return "Featured"
        case .topCharts:
            return "Top Charts"
        case .categories:
            return "Categories"
        }
    }
}

enum Item: Hashable {
    case featured(String)
    case topChart(Int, String)
    case category(String, String)
}

// MARK: - Cells

class FeaturedBannerCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.numberOfLines = 2
        
        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with title: String) {
        titleLabel.text = title
    }
}

class TopChartsCell: UICollectionViewCell {
    private let rankLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        
        rankLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        rankLabel.textColor = .label
        
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        
        contentView.addSubview(rankLabel)
        contentView.addSubview(nameLabel)
        
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            rankLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            rankLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            
            nameLabel.topAnchor.constraint(equalTo: rankLabel.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }
    
    func configure(rank: Int, appName: String) {
        rankLabel.text = "\(rank)"
        nameLabel.text = appName
    }
}

class CategoryCell: UICollectionViewCell {
    private let nameLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        
        let stackView = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(name: String, description: String) {
        nameLabel.text = name
        descriptionLabel.text = description
    }
}

// MARK: - Section Header

class SectionHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel()
    private let seeAllButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        
        var config = UIButton.Configuration.plain()
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            return outgoing
        }
        seeAllButton.configuration = config
        seeAllButton.setTitle("See All", for: .normal)
        seeAllButton.tintColor = .systemBlue
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, seeAllButton])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func configure(section: Section) {
        titleLabel.text = section.title
    }
}
```

**Key Features:**

- **Three distinct layouts:** Featured (paged horizontal scroll at 350pt), Top Charts (continuous horizontal scroll with 3 visible), Categories (vertical list at 80pt each)
- **Modern cell registration:** Uses `UICollectionViewCellRegistration` with closures instead of `register/dequeue`
- **DiffableDataSource:** Type-safe with `Section` and `Item` enums
- **Section headers:** Custom `SectionHeaderView` with title and "See All" button for each section
- **Compositional layout:** Fully configured with proper spacing, insets, and scrolling behaviors
- **Self-sizing:** Categories section uses fixed heights; headers use estimated sizing

Drop this into a Storyboard or programmatic navigation and it's ready to use.
