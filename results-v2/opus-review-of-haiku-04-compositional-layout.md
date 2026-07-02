```swift
import UIKit

// MARK: - Models

enum Section: Int, CaseIterable, Hashable {
    case featured, topCharts, categories

    var title: String {
        switch self {
        case .featured: "Featured"
        case .topCharts: "Top Charts"
        case .categories: "Categories"
        }
    }
}

struct Item: Hashable {
    let id: String
    let title: String
}

// MARK: - Main View Controller

final class AppStoreTodayViewController: UIViewController {

    private var collectionView: UICollectionView!
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
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [unowned self] sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            switch section {
            case .featured: return featuredSection()
            case .topCharts: return topChartsSection()
            case .categories: return categoriesSection()
            }
        }
    }

    // MARK: - Section Layouts

    private func makeSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    private func featuredSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.95), heightDimension: .absolute(350))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    private func topChartsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.33), heightDimension: .absolute(150))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    private func categoriesSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(80))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(80))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let featuredRegistration = UICollectionView.CellRegistration<FeaturedCell, Item> { cell, _, item in
            cell.configure(with: item)
        }
        let topChartRegistration = UICollectionView.CellRegistration<TopChartCell, Item> { cell, _, item in
            cell.configure(with: item)
        }
        let categoryRegistration = UICollectionView.CellRegistration<CategoryCell, Item> { cell, _, item in
            cell.configure(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            guard let section = Section(rawValue: indexPath.section) else { return nil }
            switch section {
            case .featured:
                return collectionView.dequeueConfiguredReusableCell(using: featuredRegistration, for: indexPath, item: item)
            case .topCharts:
                return collectionView.dequeueConfiguredReusableCell(using: topChartRegistration, for: indexPath, item: item)
            case .categories:
                return collectionView.dequeueConfiguredReusableCell(using: categoryRegistration, for: indexPath, item: item)
            }
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { supplementaryView, _, indexPath in
            guard let section = Section(rawValue: indexPath.section) else { return }
            supplementaryView.configure(with: section.title)
        }

        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems((1...4).map { Item(id: "featured-\($0)", title: "Featured App \($0)") }, toSection: .featured)
        snapshot.appendItems((1...8).map { Item(id: "topChart-\($0)", title: "App \($0)") }, toSection: .topCharts)
        snapshot.appendItems((1...6).map { Item(id: "category-\($0)", title: "Category \($0)") }, toSection: .categories)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Featured Cell

final class FeaturedCell: UICollectionViewCell {

    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        gradientLayer.colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        gradientLayer.startPoint = .zero
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        contentView.layer.insertSublayer(gradientLayer, at: 0)

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .white.withAlphaComponent(0.8)

        for label in [titleLabel, subtitleLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
        }

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }

    func configure(with item: Item) {
        titleLabel.text = item.title
        subtitleLabel.text = "An amazing app"
    }
}

// MARK: - Top Chart Cell

final class TopChartCell: UICollectionViewCell {

    private let containerView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let rankLabel = UILabel()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true
        contentView.addSubview(containerView)

        gradientLayer.colors = [UIColor.systemOrange.cgColor, UIColor.systemRed.cgColor]
        gradientLayer.startPoint = .zero
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        containerView.layer.insertSublayer(gradientLayer, at: 0)

        rankLabel.font = .systemFont(ofSize: 20, weight: .bold)
        rankLabel.textAlignment = .center

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center

        for label in [rankLabel, titleLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
        }

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 100),
            rankLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 8),
            rankLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rankLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: rankLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = containerView.bounds
    }

    func configure(with item: Item) {
        let rank = Int(item.id.split(separator: "-").last ?? "1") ?? 1
        rankLabel.text = "#\(rank)"
        titleLabel.text = item.title
    }
}

// MARK: - Category Cell

final class CategoryCell: UICollectionViewCell {

    private let iconView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let separatorView = UIView()

    private static let iconColors: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemRed, .systemPink, .systemPurple
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemBackground

        iconView.layer.cornerRadius = 8

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabel

        separatorView.backgroundColor = .separator

        for subview in [iconView, titleLabel, descriptionLabel, separatorView] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: Item) {
        titleLabel.text = item.title
        descriptionLabel.text = "Browse and discover"
        let index = Int(item.id.split(separator: "-").last ?? "1") ?? 1
        iconView.backgroundColor = Self.iconColors[(index - 1) % Self.iconColors.count]
    }
}

// MARK: - Section Header View

final class SectionHeaderView: UICollectionReusableView {

    private let titleLabel = UILabel()
    private let seeAllButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "See All"
        config.baseForegroundColor = .systemBlue
        return UIButton(configuration: config)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)

        for subview in [titleLabel, seeAllButton] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            seeAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            seeAllButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with title: String) {
        titleLabel.text = title
    }
}

// MARK: - Scene Delegate

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: AppStoreTodayViewController())
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

Key fixes:

- **Gradient layer bug**: Moved gradient creation to `init`, stored as a property, and update frame in `layoutSubviews` — the original re-inserted a new layer on every `configure` call (cell reuse would stack layers), and set `frame` to `.zero` bounds
- **Modern cell registration**: Replaced `register`/`dequeueReusableCell` with `UICollectionView.CellRegistration` and `SupplementaryRegistration`, eliminating force casts and string identifiers
- **Featured section layout**: Group is now `0.95` fractional width (not the item) with `interGroupSpacing`, so `groupPaging` snaps correctly with a peek effect
- **Removed `ItemType`**: Unused — section index already determines cell type
- **Removed unused `imageView`**: No image was ever set on it in either cell
- **`UIButton.Configuration`**: Replaced legacy `setTitle`/`setTitleColor` API
- **`.separator` color**: Used system separator color instead of `.systemGray5`
- **`Section(rawValue:)`**: Safer than `allCases[sectionIndex]` subscript
- **Removed the `UIWindowScene` extension**: Replaced with a proper `SceneDelegate`
- **Non-optional `dataSource`**: Changed from `?` to `!` since it's always configured in `viewDidLoad`
- **Removed redundant defaults**: `showsVerticalScrollIndicator = true`, `interGroupSpacing = 0`, `numberOfLines = 1`, explicit `textColor = .label`
