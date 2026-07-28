//
//  SpreadSheetView.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/9.
//

import UIKit

class SpreadSheetView: UIView {

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        
        return tableView
    }()
    
    private let viewModel: [[String]]

    public init(viewModel: [[String]]) {
        if viewModel.count < 1 {
            fatalError("less than one row")
        }
        
        self.viewModel = viewModel
        super.init(frame: .zero)
        self.backgroundColor = .clear
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(self.tableView)
        
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    
        
        tableView.register(SpreadsheetCell.self, forCellReuseIdentifier: "\(SpreadsheetCell.self)")
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
    }
}

extension SpreadSheetView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "\(SpreadsheetCell.self)", for: indexPath) as? SpreadsheetCell else {
            
            return UITableViewCell()
        }
        cell.row = indexPath.row
        
        let model = SpreadsheetItemViewModel(
            items: viewModel[indexPath.row],
            isFirstLine: indexPath.row == 0,
            isLastLine: indexPath.row == viewModel.count - 1)
        
        
        cell.update(viewModel: model)
        
        return cell
    }
}

extension SpreadSheetView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

