if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

local QBCore = exports['qb-core']:GetCoreObject()

local function exploitBan(id, reason)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            GetPlayerName(id),
            QBCore.Functions.GetIdentifier(id, 'license'),
            QBCore.Functions.GetIdentifier(id, 'discord'),
            QBCore.Functions.GetIdentifier(id, 'ip'),
            reason,
            2147483647,
            'qb-pawnshop'
        })
    TriggerEvent('qb-log:server:CreateLog', 'pawnshop', 'Player Banned', 'red',
        string.format('%s was banned by %s for %s', GetPlayerName(id), 'qb-pawnshop', reason), true)
    DropPlayer(id, 'You were permanently banned by the server for: Exploiting')
end

RegisterNetEvent('qb-pawnshop:server:sellPawnItems', function(itemName, itemAmount, itemPrice)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local totalPrice = (tonumber(itemAmount) * itemPrice)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local dist
    for _, value in pairs(Config.PawnLocation) do
        dist = #(playerCoords - value.coords)
        if #(playerCoords - value.coords) < 2 then
            dist = #(playerCoords - value.coords)
            break
        end
    end
    if dist > 5 then
        exploitBan(src, 'Sell Pawn Items Exploiting')
        return
    end
    if exports['qb-inventory']:RemoveItem(src, itemName, tonumber(itemAmount), false, 'qb-pawnshop:server:sellPawnItems') then
        if Config.BankMoney then
            Player.Functions.AddMoney('bank', totalPrice, 'qb-pawnshop:server:sellPawnItems')
        else
            Player.Functions.AddMoney('cash', totalPrice, 'qb-pawnshop:server:sellPawnItems')
        end
        if Config.Notify == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.sold', { value = tonumber(itemAmount), value2 = QBCore.Shared.Items[itemName].label, value3 = totalPrice }), 'success')
        elseif Config.Notify == 'ox' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Items Sold',
                description = Lang:t('success.sold', { value = tonumber(itemAmount), value2 = QBCore.Shared.Items[itemName].label, value3 = totalPrice }),
                position = 'center-right',
                type = 'success'
            })
        end
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    else
        if Config.Notify == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_items'), 'error')
        elseif Config.Notify == 'ox' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Missing Items',
                description = Lang:t('error.no_items'),
                position = 'center-right',
                type = 'error'
            })
        end
    end
    TriggerClientEvent('qb-pawnshop:client:openMenu', src)
end)

RegisterNetEvent('qb-pawnshop:server:meltItemRemove', function(itemName, itemAmount, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if exports['qb-inventory']:RemoveItem(src, itemName, itemAmount, false, 'qb-pawnshop:server:meltItemRemove') then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
        local meltTime = (tonumber(itemAmount) * item.time)
        TriggerClientEvent('qb-pawnshop:client:startMelting', src, item, tonumber(itemAmount), (meltTime * 60000 / 1000))
        if Config.Notify == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('info.melt_wait', { value = meltTime }), 'primary')
        elseif Config.Notify == 'ox' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Melting Items',
                description = Lang:t('info.melt_wait', { value = meltTime }),
                position = 'center-right',
                type = 'inform'
            })
        end
    else
        if Config.Notify == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_items'), 'error')
        elseif Config.Notify == 'ox' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Missing Items',
                description = Lang:t('error.no_items'),
                position = 'center-right',
                type = 'error'
            })
        end
    end
end)

RegisterNetEvent('qb-pawnshop:server:pickupMelted', function(item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local dist
    for _, value in pairs(Config.PawnLocation) do
        dist = #(playerCoords - value.coords)
        if #(playerCoords - value.coords) < 2 then
            dist = #(playerCoords - value.coords)
            break
        end
    end
    if dist > 5 then
        exploitBan(src, 'Pickup Melted Items Exploiting')
        return
    end
    for _, v in pairs(item.items) do
        local meltedAmount = v.amount
        for _, m in pairs(v.item.reward) do
            local rewardAmount = m.amount
            if exports['qb-inventory']:AddItem(src, m.item, (meltedAmount * rewardAmount), false, false, 'qb-pawnshop:server:pickupMelted') then
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[m.item], 'add')
                if Config.Notify == 'qb' then
                    TriggerClientEvent('QBCore:Notify', src, Lang:t('success.items_received', { value = (meltedAmount * rewardAmount), value2 = QBCore.Shared.Items[m.item].label }), 'success')
                elseif Config.Notify == 'ox' then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Items Received',
                        description = Lang:t('success.items_received', { value = (meltedAmount * rewardAmount), value2 = QBCore.Shared.Items[m.item].label }),
                        position = 'center-right',
                        type = 'success'
                    })
                end
                TriggerClientEvent('qb-pawnshop:client:resetPickup', src)
            else
                if Config.Notify == 'qb' then
                    TriggerClientEvent('QBCore:Notify', src, Lang:t('error.inventory_full', { value = QBCore.Shared.Items[m.item].label }), 'warning', 7500)
                elseif Config.Notify == 'ox' then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Inventory Full',
                        description = Lang:t('error.inventory_full', { value = QBCore.Shared.Items[m.item].label }),
                        duration = 7500,
                        position = 'center-right',
                        type = 'warning'
                    })
                end
            end
        end
    end
    TriggerClientEvent('qb-pawnshop:client:openMenu', src)
end)

lib.callback.register('qb-pawnshop:server:getInv', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    local inventory = Player.PlayerData.items

    return inventory
end)