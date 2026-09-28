import SwiftUI

enum CatalogState {
  case loading
  case loaded([CatalogImage])
  case failed(String)
}
