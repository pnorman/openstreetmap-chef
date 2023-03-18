name "viserion"
description "Master role applied to viserion"

default_attributes(
  :accounts => {
    :users => {
      :anovak => { :status => :administrator }
    }
  },
  :location => "Pula, Croatia",
  :munin => {
    :allow => ["193.198.233.210"]
  },
  :networking => {
    :interfaces => {
      :external => {
        :interface => "eth0",
        :role => :external,
        :inet => {
          :address => "193.198.233.211",
          :prefix => "29",
          :gateway => "193.198.233.209"
        },
        :inet6 => {
          :address => "2001:b68:4cff:3::3",
          :prefix => "64",
          :gateway => "2001:b68:4cff:3::1"
        }
      }
    }
  }
)

run_list(
  "role[carnet]"
)
