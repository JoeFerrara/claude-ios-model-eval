import UIKit

// MARK: - Models

struct FeaturedItem: Hashable {
    let id        = UUID()
    let title:    String
    let subtitle: String
    let color:    UIColor
}

struct ChartItem: Hashable {
    let id       = UUID()
    let rank:     Int
    let name:     String
    let category: String
    let color:    UIColor
}

struct CategoryItem: Hashable {
    let id   = UUID()
    let name: String
    let icon: String
    let color: UIColor
}

// MARK: - Section / Item

enum Section: Int, CaseIterable {
    case featured, topCharts, categories

    var title: String {
        switch self {
        case .featured:   return "Today"
        case .topCharts:  return "Top Charts"
        case .categories: return "Categories"
        }
    }
}

enum Item: Hashable {
    case featured(FeaturedItem)
    case chart(ChartItem)
    case category(CategoryItem)
}

// MARK: - FeaturedCell

final class FeaturedCell: UICollectionViewCell {
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true

        titleLabel.font         = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor    = .white
        titleLabel.numberOfLines = 2

        subtitleLabel.font         = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor    = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis    = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: FeaturedItem) {
        titleLabel.text    = item.title
        subtitleLabel.text = item.subtitle
        contentView.backgroundColor = item.color
    }
}

// MARK: - ChartCell

final class ChartCell: UICollectionViewCell {
    private let iconView   = UIView()
    private let rankLabel  = UILabel()
    private let nameLabel  = UILabel()
    private let genreLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView.layer.cornerRadius = 14
        iconView.clipsToBounds = true

        rankLabel.font          = .systemFont(ofSize: 22, weight: .bold)
        rankLabel.textColor     = .white
        rankLabel.textAlignment = .center

        nameLabel.font          = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor     = .label
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

        genreLabel.font          = .systemFont(ofSize: 11)
        genreLabel.textColor     = .secondaryLabel
        genreLabel.textAlignment = .center

        [iconView, rankLabel, nameLabel, genreLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        iconView.addSubview(rankLabel)
        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(genreLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.85),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            rankLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            rankLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),

            genreLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            genreLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            genreLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: ChartItem) {
        rankLabel.text  = "#\(item.rank)"
        nameLabel.text  = item.name
        genreLabel.text = item.category
        iconView.backgroundColor = item.color
    }
}

// MARK: - CategoryCell

final class CategoryCell: UICollectionViewCell {
    private let iconContainer = UIView()
    private let iconLabel     = UILabel()
    private let nameLabel     = UILabel()
    private let chevron       = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separator     = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconContainer.layer.cornerRadius = 12
        iconContainer.clipsToBounds = true

        iconLabel.font          = .systemFont(ofSize: 24)
        iconLabel.textAlignment = .center

        nameLabel.font      = .systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = .label

        chevron.tintColor    = .tertiaryLabel
        chevron.contentMode  = .scaleAspectFit

        separator.backgroundColor = .separator

        [iconContainer, iconLabel, nameLabel, chevron, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        iconContainer.addSubview(iconLabel)
        contentView.addSubview(iconContainer)
        contentView.addSubview(nameLabel)
        contentView.addSubview(chevron)
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 52),
            iconContainer.heightAnchor.constraint(equalToConstant: 52),

            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 18),

            separator.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: CategoryItem) {
        nameLabel.text  = item.name
        iconLabel.text  = item.icon
        iconContainer.backgroundColor = item.color
    }
}

// MARK: - SectionHeaderView

final class SectionHeaderView: UICollectionReusableView {
    let titleLabel = UILabel()
    let seeAllButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "See All"
        config.baseForegroundColor = .systemBlue
        config.contentInsets = .zero
        return UIButton(configuration: config)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font      = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label

        [titleLabel, seeAllButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: seeAllButton.leadingAnchor, constant: -8),

            seeAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            seeAllButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) { titleLabel.text = title }
}

// MARK: - AppStoreTodayViewController

final class AppStoreTodayViewController: UIViewController {

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot   = NSDiffableDataSourceSnapshot<Section, Item>

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!

    private lazy var featuredRegistration = UICollectionView.CellRegistration<FeaturedCell, FeaturedItem> {
        cell, _, item in cell.configure(with: item)
    }

    private lazy var chartRegistration = UICollectionView.CellRegistration<ChartCell, ChartItem> {
        cell, _, item in cell.configure(with: item)
    }

    private lazy var categoryRegistration = UICollectionView.CellRegistration<CategoryCell, CategoryItem> {
        cell, _, item in cell.configure(with: item)
    }

    private lazy var headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
        elementKind: UICollectionView.elementKindSectionHeader
    ) { view, _, indexPath in
        let section = Section(rawValue: indexPath.section)!
        view.configure(title: section.title)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "Today"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        buildCollectionView()
        buildDataSource()
        applySnapshot()
    }

    private func buildCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: buildLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func buildLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, env in
            guard let self, let section = Section(rawValue: index) else { return nil }
            switch section {
            case .featured:   return self.featuredSection()
            case .topCharts:  return self.topChartsSection(env: env)
            case .categories: return self.categoriesSection()
            }
        }
    }

    private func featuredSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(350)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 12
        section.contentInsets = .init(top: 0, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }

    private func topChartsSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let availableWidth = env.container.effectiveContentSize.width - 32
        let itemWidth      = availableWidth / 3.3

        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .absolute(itemWidth), heightDimension: .absolute(160)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 12
        section.contentInsets = .init(top: 0, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }

    private func categoriesSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80))
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 24, trailing: 0)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }

    private func sectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    private func buildDataSource() {
        dataSource = DataSource(collectionView: collectionView) { [weak self] cv, indexPath, item in
            guard let self else { return nil }
            switch item {
            case .featured(let x):
                return cv.dequeueConfiguredReusableCell(using: self.featuredRegistration,  for: indexPath, item: x)
            case .chart(let x):
                return cv.dequeueConfiguredReusableCell(using: self.chartRegistration,     for: indexPath, item: x)
            case .category(let x):
                return cv.dequeueConfiguredReusableCell(using: self.categoryRegistration,  for: indexPath, item: x)
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] cv, kind, indexPath in
            guard let self, kind == UICollectionView.elementKindSectionHeader else { return nil }
            return cv.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
        }
    }

    private func applySnapshot() {
        var snap = Snapshot()
        snap.appendSections(Section.allCases)

        snap.appendItems([
            .featured(.init(title: "Game of the Day", subtitle: "Lose yourself in an epic open world", color: .init(red: 0.18, green: 0.38, blue: 0.82, alpha: 1))),
            .featured(.init(title: "App of the Day", subtitle: "The creative tool reshaping how you work", color: .init(red: 0.80, green: 0.28, blue: 0.18, alpha: 1))),
            .featured(.init(title: "Made for You", subtitle: "Personalized picks based on what you love", color: .init(red: 0.18, green: 0.62, blue: 0.40, alpha: 1))),
            .featured(.init(title: "Editors' Choice", subtitle: "Exceptional apps our team can't stop using", color: .init(red: 0.52, green: 0.18, blue: 0.76, alpha: 1))),
        ], toSection: .featured)

        snap.appendItems([
            .chart(.init(rank: 1, name: "Phantom Quest", category: "Role Playing",  color: .init(red: 0.95, green: 0.50, blue: 0.10, alpha: 1))),
            .chart(.init(rank: 2, name: "Luminary",      category: "Productivity",  color: .init(red: 0.10, green: 0.60, blue: 0.90, alpha: 1))),
            .chart(.init(rank: 3, name: "Orion Maps",    category: "Navigation",    color: .init(red: 0.18, green: 0.75, blue: 0.48, alpha: 1))),
            .chart(.init(rank: 4, name: "Vaultify",      category: "Finance",       color: .init(red: 0.58, green: 0.28, blue: 0.90, alpha: 1))),
            .chart(.init(rank: 5, name: "Pixel Frame",   category: "Photo & Video", color: .init(red: 0.90, green: 0.20, blue: 0.40, alpha: 1))),
            .chart(.init(rank: 6, name: "Nomo Chat",     category: "Social",        color: .init(red: 0.95, green: 0.75, blue: 0.10, alpha: 1))),
        ], toSection: .topCharts)

        snap.appendItems([
            .category(.init(name: "Games",             icon: "gamecontroller", color: .init(red: 0.95, green: 0.35, blue: 0.20, alpha: 1))),
            .category(.init(name: "Productivity",      icon: "checklist", color: .init(red: 0.20, green: 0.55, blue: 0.95, alpha: 1))),
            .category(.init(name: "Health & Fitness",  icon: "heart", color: .init(red: 0.25, green: 0.75, blue: 0.45, alpha: 1))),
            .category(.init(name: "Entertainment",     icon: "film", color: .init(red: 0.75, green: 0.20, blue: 0.85, alpha: 1))),
            .category(.init(name: "Education",         icon: "book", color: .init(red: 0.95, green: 0.65, blue: 0.10, alpha: 1))),
            .category(.init(name: "Finance",           icon: "dollarsign", color: .init(red: 0.20, green: 0.70, blue: 0.60, alpha: 1))),
            .category(.init(name: "Travel",            icon: "airplane", color: .init(red: 0.40, green: 0.45, blue: 0.95, alpha: 1))),
            .category(.init(name: "Social Networking", icon: "bubble.left", color: .init(red: 0.95, green: 0.40, blue: 0.55, alpha: 1))),
        ], toSection: .categories)

        dataSource.apply(snap, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension AppStoreTodayViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .featured(let x):  print("Featured: \(x.title)")
        case .chart(let x):     print("Chart: \(x.name)")
        case .category(let x):  print("Category: \(x.name)")
        }
    }
}
