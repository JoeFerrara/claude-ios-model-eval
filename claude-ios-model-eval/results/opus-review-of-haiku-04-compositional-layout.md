```swift
import UIKit

// MARK: - Models

enum Section: Int, CaseIterable {
    case featured, topCharts, categories

    var title: String {
        switch self {
        case .featured: "Featured"
        case .topCharts: "Top Charts"
        case .categories: "Categories"
        }
    }
}

enum Item: Hashable {
    case featured(String)
    case topChart(rank: Int, name: String)
    case category(name: String, description: String)
}

// MARK: - View Controller

final class AppStoreViewController: UIViewController {

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

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
    }
}

// MARK: - Layout

private extension AppStoreViewController {

    static func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            switch section {
            case .featured: makeFeaturedSection()
            case .topCharts: makeTopChartsSection()
            case .categories: makeCategoriesSection()
            }
        }
    }

    static func makeSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    static func makeFeaturedSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )
        item.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(0.95), heightDimension: .absolute(350)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.contentInsets = .init(top: 16, leading: 0, bottom: 16, trailing: 0)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    static func makeTopChartsSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )
        item.contentInsets = .init(top: 0, leading: 8, bottom: 0, trailing: 8)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(0.35), heightDimension: .absolute(140)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.contentInsets = .init(top: 0, leading: 4, bottom: 16, trailing: 4)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    static func makeCategoriesSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )

        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 16, bottom: 16, trailing: 16)
        section.interGroupSpacing = 12
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }
}

// MARK: - Data Source

private extension AppStoreViewController {

    func configureDataSource() {
        let featuredRegistration = UICollectionView.CellRegistration<FeaturedBannerCell, Item> { cell, _, item in
            if case .featured(let title) = item {
                cell.configure(with: title)
            }
        }

        let topChartsRegistration = UICollectionView.CellRegistration<TopChartsCell, Item> { cell, _, item in
            if case .topChart(let rank, let name) = item {
                cell.configure(rank: rank, name: name)
            }
        }

        let categoriesRegistration = UICollectionView.CellRegistration<CategoryCell, Item> { cell, _, item in
            if case .category(let name, let description) = item {
                cell.configure(name: name, description: description)
            }
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { view, _, indexPath in
            guard let section = Section(rawValue: indexPath.section) else { return }
            view.configure(with: section)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .featured:
                collectionView.dequeueConfiguredReusableCell(using: featuredRegistration, for: indexPath, item: item)
            case .topChart:
                collectionView.dequeueConfiguredReusableCell(using: topChartsRegistration, for: indexPath, item: item)
            case .category:
                collectionView.dequeueConfiguredReusableCell(using: categoriesRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)

        snapshot.appendItems([
            .featured("Discover Something New"),
            .featured("Creative Apps"),
            .featured("Productivity Boost")
        ], toSection: .featured)

        snapshot.appendItems([
            .topChart(rank: 1, name: "Instagram"),
            .topChart(rank: 2, name: "TikTok"),
            .topChart(rank: 3, name: "Discord"),
            .topChart(rank: 4, name: "Snapchat"),
            .topChart(rank: 5, name: "WhatsApp")
        ], toSection: .topCharts)

        snapshot.appendItems([
            .category(name: "Games", description: "Best games to play"),
            .category(name: "Entertainment", description: "Shows and movies"),
            .category(name: "Productivity", description: "Get things done"),
            .category(name: "Health", description: "Wellness apps"),
            .category(name: "Social", description: "Connect with others")
        ], toSection: .categories)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Cells

final class FeaturedBannerCell: UICollectionViewCell {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with title: String) {
        titleLabel.text = title
    }
}

final class TopChartsCell: UICollectionViewCell {
    private let rankLabel = UILabel()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        rankLabel.font = .systemFont(ofSize: 28, weight: .bold)
        rankLabel.textColor = .label

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2

        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rankLabel)
        contentView.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            rankLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            rankLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: rankLabel.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(rank: Int, name: String) {
        rankLabel.text = "\(rank)"
        nameLabel.text = name
    }
}

final class CategoryCell: UICollectionViewCell {
    private let nameLabel = UILabel()
    private let descriptionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label

        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, description: String) {
        nameLabel.text = name
        descriptionLabel.text = description
    }
}

// MARK: - Section Header

final class SectionHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel()
    private let seeAllButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "See All"
        config.baseForegroundColor = .systemBlue
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = .systemFont(ofSize: 14, weight: .semibold)
            return attrs
        }
        return UIButton(configuration: config)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label

        let stack = UIStackView(arrangedSubviews: [titleLabel, seeAllButton])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with section: Section) {
        titleLabel.text = section.title
    }
}
```

Fixes applied:

- **`UICollectionViewCellRegistration`/`UICollectionViewSupplementaryRegistration`** — these types don't exist. Fixed to `UICollectionView.CellRegistration` and `UICollectionView.SupplementaryRegistration`.
- **Retain cycle** in the compositional layout closure capturing `self`. Layout methods are now `static` since they use no instance state.
- **Dummy layout** — the collection view was initialized with `UICollectionViewLayout()` then immediately replaced. Now uses `lazy var` with the real layout.
- **`UIButton` mixing old/new API** — `UIButton(type: .system)` + `setTitle(_:for:)` + `tintColor` alongside `UIButton.Configuration`. Now uses `UIButton(configuration:)` with `config.title` and `config.baseForegroundColor`.
- **`dataSource` optionality** — changed from `?` to `!` since it's always configured in `viewDidLoad`.
- **`Section` gains `CaseIterable`** — enables `snapshot.appendSections(Section.allCases)` instead of listing each case.
- **`Item` associated values** now use labels (`rank:`, `name:`, `description:`) for call-site clarity.
- **All classes marked `final`**; `required init?(coder:)` uses `@available(*, unavailable)`.
- **`UIFont.systemFont`** shortened to `.systemFont`; `NSCollectionLayoutSize` inits shortened to `.init`; redundant `weight: .regular` removed.
- **Organized** with `private extension` blocks instead of scattered `MARK` + `private func`.
