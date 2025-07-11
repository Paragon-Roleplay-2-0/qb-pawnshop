if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

local QBCore = exports['qb-core']:GetCoreObject()

local isMelting = false
local canTake = false
local meltTime
local meltedItem = {}

local oxInvState = GetResourceState('ox_inventory')

CreateThread(function()
    for _, value in pairs(Config.PawnLocation) do
        local blip = AddBlipForCoord(value.coords.x, value.coords.y, value.coords.z)
        SetBlipSprite(blip, 431)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        SetBlipColour(blip, 5)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Lang:t('info.title'))
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    if Config.UseTarget then
        for key, value in pairs(Config.PawnLocation) do
            exports['qb-target']:AddBoxZone('PawnShop'..key, value.coords, value.length, value.width, {
                name = 'PawnShop'..key,
                heading = value.heading,
                minZ = value.minZ,
                maxZ = value.maxZ,
                debugPoly = value.debugPoly,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'qb-pawnshop:client:openMenu',
                        icon = 'fas fa-ring',
                        label = 'Pawn Shop',
                    },
                },
                distance = value.distance
            })
        end
    else
        local zone = {}
        for key, value in pairs(Config.PawnLocation) do
            zone[#zone + 1] = BoxZone:Create(value.coords, value.length, value.width, {
                name = 'PawnShop' .. key,
                heading = value.heading,
                minZ = value.minZ,
                maxZ = value.maxZ,
            })
        end
        local pawnShopCombo = ComboZone:Create(zone, { name = 'NewPawnShopCombo', debugPoly = false })
        pawnShopCombo:onPlayerInOut(function(isPointInside)
            if isPointInside then
                lib.registerContext({
                    id = 'header_menu',
                    title = Lang:t('info.title'),
                    canClose = true,
                    position = 'offcenter-right', -- Lation UI
                    options = {
                        {
                            title = Lang:t('info.title'),
                            icon = 'fa-solid fa-sack-dollar',
                            iconColor = 'white',
                            arrow = true,
                            description = Lang:t('info.open_pawn'),
                            event = 'qb-pawnshop:client:openMenu'
                        },
                    }
                })
                lib.showContext('header_menu')
            else
                lib.hideContext()
            end
        end)
    end
end)

RegisterNetEvent('qb-pawnshop:client:openMenu', function()
    if Config.UseTimes then
        if GetClockHours() >= Config.TimeOpen and GetClockHours() <= Config.TimeClosed then
            local menuOptions = {
                {
                    title = Lang:t('info.sell'),
                    icon = 'fa-solid fa-sack-dollar',
                    iconColor = 'white',
                    arrow = true,
                    description = Lang:t('info.sell_pawn'),
                    event = 'qb-pawnshop:client:openPawn',
                    args = {
                        items = Config.PawnItems
                    }
                }
            }
            if not isMelting then
                menuOptions[#menuOptions + 1] = {
                    title = Lang:t('info.melt'),
                    icon = 'fa-solid fa-fire',
                    iconColor = 'white',
                    arrow = true,
                    description = Lang:t('info.melt_pawn'),
                    event = 'qb-pawnshop:client:openMelt',
                    args = {
                        items = Config.MeltingItems
                    }
                }
            end
            if canTake then
                menuOptions[#menuOptions + 1] = {
                    title = Lang:t('info.melt_pickup'),
                    serverEvent = 'qb-pawnshop:server:pickupMelted',
                    args = {
                        items = meltedItem
                    }
                }
            end

            lib.registerContext({
                id = 'shop_menu',
                title = Lang:t('info.title'),
                canClose = true,
                position = 'offcenter-right', -- Lation UI
                options = menuOptions
            })

            lib.showContext('shop_menu')
        else
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(Lang:t('info.pawn_closed', { value = Config.TimeOpen, value2 = Config.TimeClosed }))
            elseif Config.Notify == 'ox' then
                lib.notify({
                    title = 'Pawnshop Closed',
                    description = Lang:t('info.pawn_closed', { value = Config.TimeOpen, value2 = Config.TimeClosed }),
                    position = 'center-right',
                    type = 'error'
                })
            end
        end
    else
        local menuOptions = {
            {
                title = Lang:t('info.sell'),
                icon = 'fa-solid fa-sack-dollar',
                iconColor = 'white',
                arrow = true,
                description = Lang:t('info.sell_pawn'),
                event = 'qb-pawnshop:client:openPawn',
                args = {
                    items = Config.PawnItems
                }
            }
        }
        if not isMelting then
            menuOptions[#menuOptions + 1] = {
                title = Lang:t('info.melt'),
                icon = 'fa-solid fa-fire',
                iconColor = 'white',
                arrow = true,
                description = Lang:t('info.melt_pawn'),
                event = 'qb-pawnshop:client:openMelt',
                args = {
                    items = Config.MeltingItems
                }
            }
        end
        if canTake then
            menuOptions[#menuOptions + 1] = {
                title = Lang:t('info.melt_pickup'),
                serverEvent = 'qb-pawnshop:server:pickupMelted',
                args = {
                    items = meltedItem
                }
            }
        end

        lib.registerContext({
            id = 'shop_menu',
            title = Lang:t('info.title'),
            canClose = true,
            position = 'offcenter-right', -- Lation UI
            options = menuOptions
        })

        lib.showContext('shop_menu')
    end
end)

RegisterNetEvent('qb-pawnshop:client:openPawn', function(data)
    lib.callback('qb-pawnshop:server:getInv', false, function(inventory)
        local PlyInv = inventory
        if Config.Inventory == 'qb' then
            local menuOptions = {}
            for _, v in pairs(PlyInv) do
                for i = 1, #data.items do
                    if v.name == data.items[i].item then
                        menuOptions[#menuOptions + 1] = {
                            title = QBCore.Shared.Items[v.name].label,
                            description = Lang:t('info.sell_items', { value = data.items[i].price }),
                            event = 'qb-pawnshop:client:pawnitems',
                            args = {
                                label = QBCore.Shared.Items[v.name].label,
                                price = data.items[i].price,
                                name = v.name,
                                amount = v.amount
                            }
                        }
                    end
                end
            end

            lib.registerContext({
                id = 'pawn_menu',
                title = Lang:t('info.title'),
                menu = 'shop_menu',
                position = 'offcenter-right', -- Lation UI
                options = menuOptions
            })

            lib.showContext('pawn_menu')
        elseif Config.Inventory == 'ox' and oxInvState == 'started' then
            local menuOptions = {}
            for _, v in pairs(PlyInv) do
                for i = 1, #data.items do
                    if v.name == data.items[i].item then
                        menuOptions[#menuOptions + 1] = {
                            title = QBCore.Shared.Items[v.name].label,
                            description = Lang:t('info.sell_items', { value = data.items[i].price }),
                            event = 'qb-pawnshop:client:pawnitems',
                            args = {
                                label = QBCore.Shared.Items[v.name].label,
                                price = data.items[i].price,
                                name = v.name,
                                amount = v.count
                            }
                        }
                    end
                end
            end

            lib.registerContext({
                id = 'pawn_menu',
                title = Lang:t('info.title'),
                menu = 'shop_menu',
                position = 'offcenter-right', -- Lation UI
                options = menuOptions
            })

            lib.showContext('pawn_menu')
        end
    end)
end)

RegisterNetEvent('qb-pawnshop:client:openMelt', function(data)
    lib.callback('qb-pawnshop:server:getInv', false, function(inventory)
        local PlyInv = inventory
        if Config.Inventory == 'qb' then
            local menuOptions = {}
            for _, v in pairs(PlyInv) do
                for i = 1, #data.items do
                    if v.name == data.items[i].item then
                        menuOptions[#menuOptions + 1] = {
                            title = QBCore.Shared.Items[v.name].label,
                            description = Lang:t('info.melt_item', { value = QBCore.Shared.Items[v.name].label }),
                            event = 'qb-pawnshop:client:meltItems',
                            args = {
                                label = QBCore.Shared.Items[v.name].label,
                                reward = data.items[i].rewards,
                                name = v.name,
                                amount = v.amount,
                                time = data.items[i].meltTime
                            }
                        }
                    end
                end
            end

            lib.registerContext({
                id = 'melt_menu',
                title = Lang:t('info.melt'),
                menu = 'shop_menu',
                position = 'offcenter-right', -- Lation UI
                options = menuOptions
            })

            lib.showContext('melt_menu')
        elseif Config.Inventory == 'ox' and oxInvState == 'started' then
            local menuOptions = {}
            for _, v in pairs(PlyInv) do
                for i = 1, #data.items do
                    if v.name == data.items[i].item then
                        menuOptions[#menuOptions + 1] = {
                            title = QBCore.Shared.Items[v.name].label,
                            description = Lang:t('info.melt_item', { value = QBCore.Shared.Items[v.name].label }),
                            event = 'qb-pawnshop:client:meltItems',
                            args = {
                                label = QBCore.Shared.Items[v.name].label,
                                reward = data.items[i].rewards,
                                name = v.name,
                                amount = v.count,
                                time = data.items[i].meltTime
                            }
                        }
                    end
                end
            end

            lib.registerContext({
                id = 'melt_menu',
                title = Lang:t('info.melt'),
                menu = 'shop_menu',
                position = 'offcenter-right', -- Lation UI
                options = menuOptions
            })

            lib.showContext('melt_menu')
        end
    end)
end)

RegisterNetEvent('qb-pawnshop:client:pawnitems', function(item)
    local sellingItem = lib.inputDialog(Lang:t('info.title'), {
        {
            type = 'input',
            label = 'Item Amount:',
            description = Lang:t('info.max', { value = item.amount }),
            required = false,
            min = 1
        }
    }, {
        allowCancel = true
    })

    if not sellingItem then return end

    if sellingItem then
        if not tonumber(sellingItem[1]) then
            return
        end

        if tonumber(sellingItem[1]) > 0 then
            if tonumber(sellingItem[1]) <= item.amount then
                TriggerServerEvent('qb-pawnshop:server:sellPawnItems', item.name, tonumber(sellingItem[1]), item.price)
            else
                if Config.Notify == 'qb' then
                    QBCore.Functions.Notify(Lang:t('error.no_items'), 'error')
                elseif Config.Notify == 'ox' then
                    lib.notify({
                        title = 'Items Missing',
                        description = Lang:t('error.no_items'),
                        position = 'center-right',
                        type = 'error'
                    })
                end
            end
        else
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(Lang:t('error.negative'), 'error')
            elseif Config.Notify == 'ox' then
                lib.notify({
                    title = 'Input Error',
                    description = Lang:t('error.negative'),
                    position = 'center-right',
                    type = 'error'
                })
            end
        end
    end
end)

RegisterNetEvent('qb-pawnshop:client:meltItems', function(item)
    local meltingItem = lib.inputDialog(Lang:t('info.melt'), {
        {
            type = 'input',
            label = 'Item Amount:',
            description = Lang:t('info.max', { value = item.amount }),
            required = false,
            min = 1
        }
    }, {
        allowCancel = true
    })

    if not meltingItem then return end
    if meltingItem then
        if not tonumber(meltingItem[1]) then
            return
        end
        if meltingItem ~= nil then
            if tonumber(meltingItem[1]) > 0 then
                TriggerServerEvent('qb-pawnshop:server:meltItemRemove', item.name, tonumber(meltingItem[1]), item)
            else
                if Config.Notify == 'qb' then
                    QBCore.Functions.Notify(Lang:t('error.no_melt'), 'error')
                elseif Config.Notify == 'ox' then
                    lib.notify({
                        title = 'Items Missing',
                        description = Lang:t('error.no_melt'),
                        position = 'center-right',
                        type = 'error'
                    })
                end
            end
        else
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(Lang:t('error.no_melt'), 'error')
            elseif Config.Notify == 'ox' then
                lib.notify({
                    title = 'Items Missing',
                    description = Lang:t('error.no_melt'),
                    position = 'center-right',
                    type = 'error'
                })
            end
        end
    end
end)

RegisterNetEvent('qb-pawnshop:client:startMelting', function(item, meltingAmount, meltTimees)
    if not isMelting then
        isMelting = true
        meltTime = meltTimees
        meltedItem = {}
        CreateThread(function()
            while isMelting do
                if LocalPlayer.state.isLoggedIn then
                    meltTime = meltTime - 1
                    if meltTime <= 0 then
                        canTake = true
                        isMelting = false
                        meltedItem[#meltedItem + 1] = { item = item, amount = meltingAmount }
                        if Config.SendMeltingEmail then
                            TriggerServerEvent('qb-phone:server:sendNewMail', {
                                sender = Lang:t('info.title'),
                                subject = Lang:t('info.subject'),
                                message = Lang:t('info.message'),
                                button = {}
                            })
                        else
                            if Config.Notify == 'qb' then
                                QBCore.Functions.Notify(Lang:t('info.message'), 'success')
                            elseif Config.Notify == 'ox' then
                                lib.notify({
                                    title = 'Items Melted',
                                    description = Lang:t('info.message'),
                                    position = 'center-right',
                                    type = 'success'
                                })
                            end
                        end
                    end
                else
                    break
                end
                Wait(1000)
            end
        end)
    end
end)

RegisterNetEvent('qb-pawnshop:client:resetPickup', function()
    canTake = false
end)