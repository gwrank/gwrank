class Admin < ApplicationRecord
  devise :database_authenticatable, :lockable, :rememberable, :timeoutable
end
